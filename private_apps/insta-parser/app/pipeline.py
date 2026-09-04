"""Core processing steps: download, audio extraction, transcription, frame
extraction, and OCR. Kept separate from main.py so each step is a plain
function that FastAPI endpoints (and the /process orchestrator) can call
directly, without going through HTTP.
"""

import json
import logging
import re
import subprocess
import threading
from pathlib import Path

import instaloader
import pytesseract
from PIL import Image
from rapidfuzz import fuzz

from . import config
from . import places as places_module

logger = logging.getLogger("insta_parser")

SHORTCODE_RE = re.compile(r"instagram\.com/(?:p|reel|reels|tv)/([A-Za-z0-9_-]+)")


class PipelineError(Exception):
    """A user-facing pipeline failure (rate-limited, ffmpeg error, ...)."""


class InvalidInputError(PipelineError):
    """Bad input from the caller — surfaces as a 400 rather than a 502."""


def extract_shortcode(url: str) -> str:
    match = SHORTCODE_RE.search(url)
    if not match:
        raise InvalidInputError(
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
        raise InvalidInputError(f"Post '{shortcode}' has no video (not a reel/video post)")

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

    # Every field below is a lazy property that can hit the network, so any of
    # them may fail with a rate-limit error even though the video downloaded.
    try:
        location = post.location.name if post.location else None
    except instaloader.exceptions.InstaloaderException as exc:
        logger.warning("Could not fetch location for %s: %s", shortcode, exc)
        location = None

    try:
        username = post.owner_username
    except instaloader.exceptions.InstaloaderException as exc:
        logger.warning("Could not fetch owner username for %s: %s", shortcode, exc)
        username = "Unknown"

    try:
        metadata = {
            "shortcode": shortcode,
            "username": username,
            "caption": post.caption or "",
            "timestamp": post.date_utc.isoformat(),
            "like_count": post.likes,
            "comment_count": post.comments,
            "location": location,
            "video_path": str(video_path),
        }
    except instaloader.exceptions.InstaloaderException as exc:
        logger.error("Failed to read metadata for %s: %s", shortcode, exc)
        raise PipelineError(f"Failed to read metadata for '{shortcode}': {exc}") from exc

    (job_dir / "metadata.json").write_text(json.dumps(metadata, indent=2))
    return metadata


def _video_path(job_dir: Path) -> Path:
    video_path = job_dir / "video.mp4"
    if not video_path.exists():
        raise PipelineError(f"No downloaded video for this job (expected {video_path}); call /download first")
    return video_path


def _run_ffmpeg(cmd: list[str], step: str) -> None:
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=config.FFMPEG_TIMEOUT
        )
    except FileNotFoundError:
        logger.error("ffmpeg binary not found on PATH")
        raise PipelineError(
            "ffmpeg is not installed in this container — the image should install it via apt"
        )
    except subprocess.TimeoutExpired:
        logger.error("ffmpeg %s timed out after %ss (cmd=%s)", step, config.FFMPEG_TIMEOUT, " ".join(cmd))
        raise PipelineError(
            f"ffmpeg timed out after {config.FFMPEG_TIMEOUT}s during {step} "
            "(raise FFMPEG_TIMEOUT if this video is genuinely long)"
        )
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
    # -vsync vfr keeps only the frames the select filter passes. Newer ffmpeg
    # builds prefer -fps_mode vfr but still accept -vsync with a warning.
    _run_ffmpeg(
        [
            "ffmpeg", "-y", "-i", str(video_path),
            "-vf", f"select='gt(scene,{config.SCENE_THRESHOLD})',scale=-2:{config.FRAME_SCALE_HEIGHT}",
            "-vsync", "vfr",
            "-frames:v", str(config.MAX_FRAMES),
            "-an",
            str(frames_dir / "frame_%04d.png"),
        ],
        step="frame extraction",
    )
    frames = sorted(frames_dir.glob("frame_*.png"))
    if len(frames) >= config.MAX_FRAMES:
        logger.warning(
            "Frame extraction hit the MAX_FRAMES cap (%d); later scene changes were dropped",
            config.MAX_FRAMES,
        )
    return frames


_whisper_model = None
_whisper_model_lock = threading.Lock()
# Sync endpoints run in FastAPI's threadpool, so this bounds how many
# transcriptions compete for CPU at once.
_transcribe_semaphore = threading.Semaphore(config.TRANSCRIBE_CONCURRENCY)


def _get_whisper_model():
    global _whisper_model
    # Double-checked locking: without the lock two threadpool workers can each
    # build a WhisperModel (hundreds of MB) and one of them is then orphaned.
    if _whisper_model is None:
        with _whisper_model_lock:
            if _whisper_model is None:
                from faster_whisper import WhisperModel

                logger.info(
                    "Loading faster-whisper model '%s' (device=%s, compute_type=%s)",
                    config.WHISPER_MODEL, config.WHISPER_DEVICE, config.WHISPER_COMPUTE_TYPE,
                )
                _whisper_model = WhisperModel(
                    config.WHISPER_MODEL,
                    device=config.WHISPER_DEVICE,
                    compute_type=config.WHISPER_COMPUTE_TYPE,
                )
    return _whisper_model


def transcribe(job_dir: Path) -> dict:
    audio_path = job_dir / "audio.mp3"
    if not audio_path.exists():
        raise PipelineError(f"No extracted audio for this job (expected {audio_path}); call /extract-audio first")

    model = _get_whisper_model()
    try:
        with _transcribe_semaphore:
            segments_gen, info = model.transcribe(str(audio_path))
            # transcribe() returns a lazy generator; it must be drained inside
            # the semaphore or the real work happens after we release it.
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


def _ocr_frame(frame: Path) -> tuple[str, float]:
    """OCR one frame, returning its text and mean word confidence."""
    # Image.open is lazy: PIL releases the fd once the image is fully read, but
    # not if the consumer raises first. The context manager makes it deterministic.
    with Image.open(frame) as img:
        data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)

    # Pair each word with its own confidence; tesseract emits rows for
    # whitespace-only boxes whose low confidence would skew the average.
    scored = [
        (word.strip(), float(conf))
        for word, conf in zip(data["text"], data["conf"])
        if word.strip() and str(conf) != "-1"
    ]
    if not scored:
        return "", 0.0

    text = " ".join(word for word, _ in scored)
    confidence = round(sum(conf for _, conf in scored) / len(scored), 1)
    return text, confidence


def run_ocr(job_dir: Path) -> list[dict]:
    frames_dir = job_dir / "frames"
    frames = sorted(frames_dir.glob("frame_*.png"))
    if not frames:
        raise PipelineError(
            f"No extracted frames for this job (expected files under {frames_dir}); call /extract-frames first"
        )

    results = []
    last_text = None
    for frame in frames:
        try:
            text, confidence = _ocr_frame(frame)
        except pytesseract.TesseractNotFoundError:
            # Not a per-frame problem: every frame would fail the same way, and
            # swallowing it would return an empty result set as if it succeeded.
            logger.error("tesseract binary not found on PATH")
            raise PipelineError(
                "tesseract is not installed in this container — the image should install it via apt"
            )
        except Exception as exc:
            logger.warning("Tesseract failed on %s: %s", frame, exc)
            continue

        if not text:
            continue
        if last_text is not None and fuzz.ratio(text, last_text) >= config.OCR_DEDUPE_THRESHOLD:
            continue

        results.append({"frame": str(frame), "text": text, "confidence": confidence})
        last_text = text

    (job_dir / "ocr.json").write_text(json.dumps(results, indent=2))
    return results


def build_places(job_dir: Path) -> list[dict]:
    metadata_path = job_dir / "metadata.json"
    if not metadata_path.exists():
        raise PipelineError(f"No downloaded metadata for this job (expected {metadata_path}); call /download first")
    metadata = json.loads(metadata_path.read_text())

    transcript_path = job_dir / "transcript.json"
    transcript = json.loads(transcript_path.read_text()) if transcript_path.exists() else None

    ocr_path = job_dir / "ocr.json"
    ocr_results = json.loads(ocr_path.read_text()) if ocr_path.exists() else None

    places = places_module.build_places_metadata(metadata, transcript, ocr_results)
    (job_dir / "places.json").write_text(json.dumps(places, indent=2))
    return places
