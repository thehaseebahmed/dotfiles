"""Core processing steps: download, audio extraction, transcription, frame
extraction, and OCR. Kept separate from main.py so each step is a plain
function that FastAPI endpoints (and the /process orchestrator) can call
directly, without going through HTTP.
"""

import json
import logging
import re
import subprocess
from pathlib import Path

import instaloader
import pytesseract
from PIL import Image
from rapidfuzz import fuzz

from . import config

logger = logging.getLogger("reel_processor")

SHORTCODE_RE = re.compile(r"instagram\.com/(?:p|reel|reels|tv)/([A-Za-z0-9_-]+)")


class PipelineError(Exception):
    """A user-facing pipeline failure (bad input, rate-limited, ffmpeg error, ...)."""


def extract_shortcode(url: str) -> str:
    match = SHORTCODE_RE.search(url)
    if not match:
        raise PipelineError(
            f"Could not find an Instagram shortcode in URL: {url!r} "
            "(expected something like instagram.com/p/<code>/ or /reel/<code>/)"
        )
    return match.group(1)


def download_post(url: str, job_dir: Path) -> dict:
    shortcode = extract_shortcode(url)
    job_dir.mkdir(parents=True, exist_ok=True)

    loader = instaloader.Instaloader(
        dirname_pattern=str(job_dir),
        filename_pattern="video",
        download_videos=True,
        download_video_thumbnails=False,
        download_pictures=False,
        download_geotags=False,
        download_comments=False,
        save_metadata=False,
        post_metadata_txt_pattern="",
        quiet=True,
    )

    if config.IG_USERNAME and config.IG_SESSION_FILE:
        try:
            loader.load_session_from_file(config.IG_USERNAME, config.IG_SESSION_FILE)
            logger.info("Loaded Instagram session for %s", config.IG_USERNAME)
        except Exception as exc:
            logger.warning("Could not load IG session (%s), continuing anonymously", exc)

    try:
        post = instaloader.Post.from_shortcode(loader.context, shortcode)
    except instaloader.exceptions.InstaloaderException as exc:
        logger.error("Failed to fetch post %s: %s", shortcode, exc)
        raise PipelineError(
            f"Failed to fetch Instagram post '{shortcode}' "
            f"(private/removed post, or rate-limited?): {exc}"
        ) from exc

    if not post.is_video:
        raise PipelineError(f"Post '{shortcode}' has no video (not a reel/video post)")

    try:
        loader.download_post(post, target=shortcode)
    except instaloader.exceptions.InstaloaderException as exc:
        logger.error("Failed to download video for %s: %s", shortcode, exc)
        raise PipelineError(f"Failed to download video for '{shortcode}': {exc}") from exc

    video_files = sorted(job_dir.glob("*.mp4"))
    if not video_files:
        raise PipelineError(f"Instaloader reported success but no .mp4 file was found in {job_dir}")
    if len(video_files) > 1:
        logger.warning("Post %s has %d videos; only processing the first one", shortcode, len(video_files))

    video_path = video_files[0]
    if video_path.name != "video.mp4":
        video_path = video_path.rename(job_dir / "video.mp4")

    location = None
    try:
        if post.location:
            location = post.location.name
    except instaloader.exceptions.InstaloaderException as exc:
        logger.warning("Could not fetch location for %s: %s", shortcode, exc)

    metadata = {
        "shortcode": shortcode,
        "caption": post.caption or "",
        "timestamp": post.date_utc.isoformat(),
        "like_count": post.likes,
        "comment_count": post.comments,
        "location": location,
        "video_path": str(video_path),
    }
    (job_dir / "metadata.json").write_text(json.dumps(metadata, indent=2))
    return metadata


def _video_path(job_dir: Path) -> Path:
    video_path = job_dir / "video.mp4"
    if not video_path.exists():
        raise PipelineError(f"No downloaded video for this job (expected {video_path}); call /download first")
    return video_path


def _run_ffmpeg(cmd: list[str], step: str) -> None:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        stderr_tail = "\n".join(result.stderr.strip().splitlines()[-10:])
        logger.error("ffmpeg %s failed (cmd=%s):\n%s", step, " ".join(cmd), stderr_tail)
        raise PipelineError(f"ffmpeg failed during {step}: {stderr_tail or 'unknown error'}")


def extract_audio(job_dir: Path) -> Path:
    video_path = _video_path(job_dir)
    audio_path = job_dir / "audio.mp3"
    _run_ffmpeg(
        ["ffmpeg", "-y", "-i", str(video_path), "-vn", "-acodec", "libmp3lame", str(audio_path)],
        step="audio extraction",
    )
    return audio_path


def extract_frames(job_dir: Path) -> list[Path]:
    video_path = _video_path(job_dir)
    frames_dir = job_dir / "frames"
    frames_dir.mkdir(exist_ok=True)
    _run_ffmpeg(
        [
            "ffmpeg", "-y", "-i", str(video_path),
            "-vf", "select='gt(scene,0.3)'",
            "-vsync", "vfr",
            str(frames_dir / "frame_%04d.png"),
        ],
        step="frame extraction",
    )
    return sorted(frames_dir.glob("frame_*.png"))


_whisper_model = None


def _get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel

        logger.info(
            "Loading faster-whisper model '%s' (device=%s, compute_type=%s)",
            config.WHISPER_MODEL, config.WHISPER_DEVICE, config.WHISPER_COMPUTE_TYPE,
        )
        _whisper_model = WhisperModel(
            config.WHISPER_MODEL, device=config.WHISPER_DEVICE, compute_type=config.WHISPER_COMPUTE_TYPE
        )
    return _whisper_model


def transcribe(job_dir: Path) -> dict:
    audio_path = job_dir / "audio.mp3"
    if not audio_path.exists():
        raise PipelineError(f"No extracted audio for this job (expected {audio_path}); call /extract-audio first")

    model = _get_whisper_model()
    try:
        segments_gen, info = model.transcribe(str(audio_path))
        segments = [
            {"start": seg.start, "end": seg.end, "text": seg.text.strip()}
            for seg in segments_gen
        ]
    except Exception as exc:
        logger.error("Transcription failed for %s: %s", job_dir, exc)
        raise PipelineError(f"Transcription failed: {exc}") from exc

    result = {
        "text": " ".join(seg["text"] for seg in segments).strip(),
        "segments": segments,
        "language": info.language,
    }
    (job_dir / "transcript.json").write_text(json.dumps(result, indent=2))
    return result


def run_ocr(job_dir: Path) -> list[dict]:
    frames_dir = job_dir / "frames"
    frames = sorted(frames_dir.glob("frame_*.png"))
    if not frames:
        raise PipelineError(f"No extracted frames for this job (expected files under {frames_dir}); call /extract-frames first")

    results = []
    last_text = None
    for frame in frames:
        try:
            data = pytesseract.image_to_data(Image.open(frame), output_type=pytesseract.Output.DICT)
        except Exception as exc:
            logger.warning("Tesseract failed on %s: %s", frame, exc)
            continue

        words = [w.strip() for w in data["text"] if w.strip()]
        text = " ".join(words)
        if not text:
            continue

        confidences = [float(c) for c in data["conf"] if str(c) != "-1"]
        confidence = round(sum(confidences) / len(confidences), 1) if confidences else 0.0

        if last_text is not None and fuzz.ratio(text, last_text) >= config.OCR_DEDUPE_THRESHOLD:
            continue

        results.append({"frame": str(frame), "text": text, "confidence": confidence})
        last_text = text

    (job_dir / "ocr.json").write_text(json.dumps(results, indent=2))
    return results
