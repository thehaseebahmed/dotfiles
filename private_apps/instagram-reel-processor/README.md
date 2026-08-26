# instagram-reel-processor

Small FastAPI microservice that downloads an Instagram post/reel, extracts
its audio + candidate frames, transcribes the audio (faster-whisper), and
OCRs the frames (Tesseract). Built to be called from n8n via HTTP.

Each job gets its own subfolder under `WORK_DIR` (a random `job_id`), so the
per-step endpoints can be called independently and re-run without stepping
on each other.

## Endpoints

- `GET  /health` — health check
- `POST /download` — fetch a post and download its video
- `POST /extract-audio` — extract mp3 audio from the downloaded video
- `POST /transcribe` — transcribe the audio with faster-whisper
- `POST /extract-frames` — grab scene-change frames as PNGs
- `POST /ocr` — OCR the extracted frames (deduping near-identical results)
- `POST /process` — runs all of the above in one call and returns the
  combined result; deletes the job's files afterwards unless
  `KEEP_FILES=true`

## Configuration (env vars)

| Var | Default | Notes |
|---|---|---|
| `WORK_DIR` | `/data` | Root dir for per-job files, mount as a volume |
| `IG_USERNAME` | unset | Instagram username for an authenticated session |
| `IG_SESSION_FILE` | unset | Path to an instaloader session file (see below) |
| `KEEP_FILES` | `false` | Keep job files after `/process` returns |
| `WHISPER_MODEL` | `base` | faster-whisper model size (`tiny`, `base`, `small`, ...) |
| `WHISPER_DEVICE` | `cpu` | faster-whisper device |
| `WHISPER_COMPUTE_TYPE` | `int8` | faster-whisper compute type |
| `OCR_DEDUPE_THRESHOLD` | `90` | rapidfuzz similarity (0-100) above which consecutive OCR text is dropped as a duplicate |
| `LOG_LEVEL` | `INFO` | Python logging level |

### Optional authenticated Instagram session

Anonymous access works for public posts but is more likely to get
rate-limited. To use a logged-in session:

```bash
pip install instaloader
instaloader --login=<your_ig_username>
# creates ~/.config/instaloader/session-<your_ig_username>
```

Copy that session file into the `WORK_DIR` volume (so it persists) and set:

```yaml
environment:
    IG_USERNAME: "your_ig_username"
    IG_SESSION_FILE: "/data/session-your_ig_username"
```

## Running

Merge `docker-compose.yaml` into your existing stack, then:

```bash
cd ~/apps/instagram-reel-processor
docker-compose up -d
docker-compose logs -f
```

The service listens on `8000` inside the container, mapped to `8420` on the
host by default.

## Example usage

```bash
BASE=http://localhost:8420

# 1. Download
curl -sX POST $BASE/download \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://www.instagram.com/reel/ABC123xyz/"}'
# => {"job_id": "...", "metadata": {"caption": "...", "timestamp": "...", ...}}

JOB_ID=<job_id from above>

# 2. Extract audio
curl -sX POST $BASE/extract-audio \
  -H 'Content-Type: application/json' \
  -d "{\"job_id\": \"$JOB_ID\"}"

# 3. Transcribe
curl -sX POST $BASE/transcribe \
  -H 'Content-Type: application/json' \
  -d "{\"job_id\": \"$JOB_ID\"}"

# 4. Extract frames
curl -sX POST $BASE/extract-frames \
  -H 'Content-Type: application/json' \
  -d "{\"job_id\": \"$JOB_ID\"}"

# 5. OCR
curl -sX POST $BASE/ocr \
  -H 'Content-Type: application/json' \
  -d "{\"job_id\": \"$JOB_ID\"}"

# All-in-one (cleans up job files afterwards unless KEEP_FILES=true)
curl -sX POST $BASE/process \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://www.instagram.com/reel/ABC123xyz/"}'

# Health check
curl -s $BASE/health
```

## n8n notes

- `/process` runs the whole pipeline synchronously in one request; for longer
  videos this can take a couple of minutes on modest homelab hardware
  (whisper transcription is the slow step). Bump the timeout on n8n's HTTP
  Request node accordingly, or call the per-step endpoints separately if you
  want more granular progress/retries.
- Errors from Instagram (rate-limiting, private/removed posts) and from
  ffmpeg/tesseract failures are returned as JSON `{"detail": "..."}` with a
  4xx/5xx status, and are also logged with the `job_id` via `docker-compose
  logs -f` for debugging.
