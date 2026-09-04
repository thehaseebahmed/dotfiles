# insta-parser

Small FastAPI microservice that downloads an Instagram post/reel, extracts
its audio + candidate frames, transcribes the audio (faster-whisper), and
OCRs the frames (Tesseract). Built to be called from n8n via HTTP.

Each job gets its own subfolder under `WORK_DIR` (a random `job_id`), so the
per-step endpoints can be called independently and re-run without stepping
on each other.

Agent-facing docs live in [`skills/`](skills/) — `insta-parser-api` for calling
the service, `insta-parser-ops` for running it. A minimal CLI wrapper over the
`/process`+`/jobs` path lives in [`cli/`](cli/) — see its README for setup;
it's not published to npm, run it from a clone of this repo.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/download` | Fetch a post and download its video. Synchronous. |
| `POST` | `/extract-audio` | Extract mp3 audio from the downloaded video |
| `POST` | `/transcribe` | Transcribe the audio with faster-whisper |
| `POST` | `/extract-frames` | Grab scene-change frames as PNGs |
| `POST` | `/ocr` | OCR the extracted frames, deduping near-identical results |
| `POST` | `/extract-places` | Extract place mentions and resolve them via Google Maps (optional, see below) |
| `POST` | `/process` | **Async.** Queues the full pipeline, returns `202` + a `job_id` |
| `GET` | `/jobs/{job_id}` | Status/result of a `/process` run |
| `DELETE` | `/jobs/{job_id}` | Delete a job's files |

The per-step endpoints are synchronous — each finishes well inside a normal
HTTP timeout. `/process` is not: whisper transcription alone can run for
minutes, so it returns immediately and you poll `/jobs/{job_id}`.

## Configuration (env vars)

| Var | Default | Notes |
|---|---|---|
| `WORK_DIR` | `/data` | Root dir for per-job files, mount as a volume |
| `IG_USERNAME` | unset | Instagram username for an authenticated session |
| `IG_SESSION_FILE` | unset | Path to an instaloader session file (see below) |
| `KEEP_FILES` | `false` | Keep job files after `/process` finishes |
| `JOB_TTL_HOURS` | `24` | Job folders older than this are swept on startup and hourly |
| `WHISPER_MODEL` | `base` | faster-whisper model size (`tiny`, `base`, `small`, ...) |
| `WHISPER_DEVICE` | `cpu` | faster-whisper device |
| `WHISPER_COMPUTE_TYPE` | `int8` | faster-whisper compute type |
| `TRANSCRIBE_CONCURRENCY` | `1` | How many transcriptions may run at once |
| `FFMPEG_TIMEOUT` | `300` | Per-invocation ffmpeg timeout, seconds |
| `MAX_FRAMES` | `60` | Cap on extracted frames per video |
| `FRAME_SCALE_HEIGHT` | `720` | Frames are downscaled to this height before OCR |
| `SCENE_THRESHOLD` | `0.3` | ffmpeg scene-change sensitivity (higher = fewer frames) |
| `OCR_DEDUPE_THRESHOLD` | `90` | rapidfuzz similarity (0-100) above which consecutive OCR text is dropped as a duplicate |
| `LOG_LEVEL` | `INFO` | Python logging level |
| `LITELLM_BASE_URL` | unset | Base URL of the self-hosted litellm proxy, **without** a `/v1` suffix (e.g. `http://172.17.0.1:4000`) |
| `LITELLM_API_KEY` | unset | Bearer key for the litellm proxy, if it requires one |
| `LITELLM_MODEL` | unset | Model alias already registered in litellm (e.g. a local Ollama model) to use for place extraction |
| `LITELLM_TIMEOUT` | `60` | Timeout (seconds) for the litellm extraction call |
| `PLACE_EXTRACTION_MAX_CHARS` | `4000` | How much combined caption/transcript/OCR text to send to the model |
| `GOOGLE_MAPS_API_KEY` | unset | Google Maps Places API (New) key, used to resolve extracted places to a rating + Maps URL |
| `GOOGLE_MAPS_TIMEOUT` | `10` | Timeout (seconds) for each Places API lookup |

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
cd ~/apps/insta-parser
docker-compose up -d
docker-compose logs -f
```

The service listens on `8000` inside the container, mapped to `8420` on the
host by default. It's deliberately not exposed via `tailscale-serve.sh` —
there's no auth on it, and n8n reaches it over the local docker bridge.

## Example usage

```bash
BASE=http://localhost:8420

# Health check
curl -s $BASE/health
# => {"status":"ok"}
```

### All-in-one (async)

```bash
# Queue the job — returns immediately with 202
curl -sX POST $BASE/process \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://www.instagram.com/reel/ABC123xyz/"}'
# => {"job_id": "3f1c...", "status": "queued"}

# Poll until status is "done" (or "error")
curl -s $BASE/jobs/3f1c...
# => {"job_id":"3f1c...","status":"running","step":"transcribe","result":null,"error":null}
# => {"job_id":"3f1c...","status":"done","step":null,"result":{"metadata":{"username":"...",
#     "places":[{"name":"Joe's Pizza","city":"Rome","country":"Italy","rating":4.6,
#                "maps_url":"https://maps.google.com/?cid=..."}], ...},
#     "transcript":{"text":"...","segments":[...]},"ocr_results":[...]},"error":null}
```

In n8n: an HTTP Request node for `POST /process`, then a Wait node, then an
HTTP Request node for `GET /jobs/{{ $json.job_id }}` in a loop with an IF node
checking `status == "done"`.

### Step by step (synchronous)

```bash
# 1. Download
curl -sX POST $BASE/download \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://www.instagram.com/reel/ABC123xyz/"}'
# => {"job_id": "...", "metadata": {"username": "...", "caption": "...", "timestamp": "...", ...}}

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

# 6. Clean up when the workflow is done with it
curl -sX DELETE $BASE/jobs/$JOB_ID
# => {"job_id": "...", "status": "deleted"}
```

## Place-metadata enrichment (optional)

If configured, `/process` (and the standalone `/extract-places` step) pull
place mentions — restaurants, landmarks, cities — out of the reel's caption,
tagged location, transcript, and OCR text, and attach them as
`metadata.places`: an array of `{name, city, country, rating, maps_url}`.

This is two independent, optional pieces:

1. **Extraction** goes through the existing self-hosted `litellm` proxy
   (`private_apps/litellm`) rather than adding a new model dependency to this
   service — point `LITELLM_MODEL` at whatever model alias you've registered
   there (a local Ollama model or otherwise). Set `LITELLM_BASE_URL` to the
   proxy's base URL. **Note:** insta-parser runs on the default bridge
   network and litellm sits on its own compose network, so — same caveat as
   reaching insta-parser itself from n8n (see "Reaching the service" in the
   API skill) — a container name won't resolve; use the host's `docker0`
   gateway IP (typically `172.17.0.1`) or LAN/Tailscale address instead.
2. **Resolution** looks each extracted place up via the [Google Maps Places
   API (New)](https://developers.google.com/maps/documentation/places/web-service/text-search)
   for a rating and canonical Maps URL. Requires a `GOOGLE_MAPS_API_KEY` with
   that API enabled on its Google Cloud project — each lookup is a billable
   request.

Leave either unset and that piece is simply omitted: no `LITELLM_MODEL` means
`places` extraction doesn't run at all (no `places` key added); no
`GOOGLE_MAPS_API_KEY` means extracted places still come back but with
`rating`/`maps_url` set to `null`. A failed litellm or Maps call is logged and
treated the same as unconfigured — it never fails `/process`.

## Notes

- **Job state is in memory.** A container restart loses the status of any
  in-flight or completed `/process` run (the files on the volume survive).
  Fine for a homelab tool; don't build a long-running workflow that assumes
  otherwise. Finished job records are evicted after `JOB_TTL_HOURS`, so
  fetch a result before then — the same sweep keeps them from accumulating.
- **Cleanup.** `/process` deletes its job folder when it finishes unless
  `KEEP_FILES=true`. The per-step endpoints don't, so either call
  `DELETE /jobs/{job_id}` at the end of your workflow or let the
  `JOB_TTL_HOURS` sweep collect them.
- **Response paths.** When `KEEP_FILES=false`, `/process` omits `video_path`
  and per-frame paths from its result, since those files no longer exist.
- **Concurrency.** Each in-flight `/process` run holds one of FastAPI's
  threadpool workers, and `TRANSCRIBE_CONCURRENCY` (default 1) queues the
  whisper step so parallel jobs don't thrash the CPU. `/health` and
  `GET /jobs/{job_id}` are async, so polling stays responsive no matter how
  many pipelines are running.
- **Error codes.** `400` = bad input (unparseable URL, malformed `job_id`,
  non-video post), `404` = unknown `job_id`, `422` = a step ran out of order
  (e.g. `/ocr` before `/extract-frames`), `502` = Instagram fetch failed
  (rate-limited, private, or removed post). Errors are also logged with the
  `job_id` and step, visible via `docker-compose logs -f`.
- **ffmpeg deprecation.** Frame extraction uses `-vsync vfr`; ffmpeg 6+ warns
  and prefers `-fps_mode vfr`. Debian's build still accepts `-vsync`.
