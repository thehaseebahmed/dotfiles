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

# Optional place-metadata enrichment. Both are independent and optional: leave
# either unset and that piece of enrichment is skipped rather than failing
# /process, since this is metadata on top of the core result, not a hard
# dependency of it.
#
# Extraction goes through the existing self-hosted litellm proxy so it can
# point at whatever model you have registered there (a local Ollama model or
# otherwise) rather than adding a new dependency to this service. Set
# LITELLM_BASE_URL to the proxy's OpenAI-compatible base URL *without* a /v1
# suffix (e.g. "http://172.17.0.1:4000" — see the litellm/n8n cross-container
# networking note in the README for why the docker0 gateway IP is usually
# needed instead of a container name), and LITELLM_MODEL to a model alias
# already registered in litellm. LITELLM_API_KEY is only needed if the proxy
# requires one.
LITELLM_BASE_URL = os.environ.get("LITELLM_BASE_URL")
LITELLM_API_KEY = os.environ.get("LITELLM_API_KEY")
LITELLM_MODEL = os.environ.get("LITELLM_MODEL")
LITELLM_TIMEOUT = int(os.environ.get("LITELLM_TIMEOUT", "60"))

# How much combined text (caption + tagged location + transcript + OCR) to send
# to the model, in characters — bounds token usage/latency on long reels.
PLACE_EXTRACTION_MAX_CHARS = int(os.environ.get("PLACE_EXTRACTION_MAX_CHARS", "4000"))

# Google Maps Places API (New) key, used to resolve each extracted place to a
# rating and canonical Maps URL. Needs the "Places API (New)" enabled on the
# associated Google Cloud project; each lookup is a billable request.
GOOGLE_MAPS_API_KEY = os.environ.get("GOOGLE_MAPS_API_KEY")
GOOGLE_MAPS_TIMEOUT = int(os.environ.get("GOOGLE_MAPS_TIMEOUT", "10"))
