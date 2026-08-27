import os

# Root directory where per-job subfolders (video, audio, frames, transcript...) are stored.
WORK_DIR = os.environ.get("WORK_DIR", "/data")

# Optional authenticated Instagram session, used instead of anonymous access.
# Create the session file locally with `instaloader --login=<username>` and mount it
# into the container, then point IG_SESSION_FILE at that path.
IG_USERNAME = os.environ.get("IG_USERNAME")
IG_SESSION_FILE = os.environ.get("IG_SESSION_FILE")

# Keep per-job files around after /process instead of deleting them.
KEEP_FILES = os.environ.get("KEEP_FILES", "false").lower() == "true"

# Job folders older than this are swept on startup and hourly thereafter.
JOB_TTL_HOURS = float(os.environ.get("JOB_TTL_HOURS", "24"))

# faster-whisper model settings. "base" on CPU is a reasonable speed/accuracy default
# for short reels; bump to "small"/"medium" if you have the CPU (or a GPU) to spare.
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "base")
WHISPER_DEVICE = os.environ.get("WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE_TYPE = os.environ.get("WHISPER_COMPUTE_TYPE", "int8")

# How many transcriptions may run at once. Whisper is CPU-hungry, so letting several
# run in parallel on a homelab box makes them all slower. Queue them instead.
TRANSCRIBE_CONCURRENCY = int(os.environ.get("TRANSCRIBE_CONCURRENCY", "1"))

# Hard ceiling on a single ffmpeg invocation, so a hung encode can't pin a worker.
FFMPEG_TIMEOUT = int(os.environ.get("FFMPEG_TIMEOUT", "300"))

# Scene-change detection on a high-motion reel can emit hundreds of frames; cap the
# count and downscale them, since OCR doesn't benefit from full resolution.
MAX_FRAMES = int(os.environ.get("MAX_FRAMES", "60"))
FRAME_SCALE_HEIGHT = int(os.environ.get("FRAME_SCALE_HEIGHT", "720"))
SCENE_THRESHOLD = os.environ.get("SCENE_THRESHOLD", "0.3")

# rapidfuzz similarity (0-100) above which consecutive OCR frame results are
# considered duplicates and dropped.
OCR_DEDUPE_THRESHOLD = float(os.environ.get("OCR_DEDUPE_THRESHOLD", "90"))

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
