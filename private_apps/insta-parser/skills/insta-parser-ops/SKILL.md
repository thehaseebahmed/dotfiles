---
name: insta-parser-ops
description: Diagnose and fix the self-hosted insta-parser container — failing requests, Instagram rate limiting, ffmpeg or tesseract errors, slow transcription, disk usage, and session login setup. Use when insta-parser returns errors, hangs, or needs configuration changed, rather than when simply calling its API.
---

# Operating insta-parser

Troubleshooting and configuration for the `insta-parser` container. For
*calling* the service, use the `insta-parser-api` skill instead.

Runs on homelab machines from `~/apps/insta-parser`. Config lives in
`docker-compose.yaml`; all tuning is via environment variables.

## First moves

```bash
cd ~/apps/insta-parser
docker compose ps                 # is it up?
curl -s localhost:8420/health     # does it answer?
docker compose logs --tail=100    # what went wrong?
```

Logs are structured and unbuffered, one line per step:

```
2026-01-02 03:04:05 INFO insta_parser: job=3f1c... step=transcribe
2026-01-02 03:04:09 ERROR insta_parser: job=3f1c... step=download failed: ...
```

Grep a single job with `docker compose logs | grep <job_id>`. Every failure
logs the `job_id` and the step that failed, so start there rather than
guessing.

Standard lifecycle:

```bash
docker compose up -d          # start
docker compose restart        # restart
docker compose down           # stop
docker compose up -d --build  # rebuild after changing the code
```

Code changes need `--build` — the image is built from the local `Dockerfile`,
not pulled.

## Symptom → cause

### `502` on every download

Instagram rate limiting, the most common failure. Anonymous access has a low
ceiling and gets stricter the more you retry.

1. Stop retrying. Wait several minutes.
2. If it persists, configure an authenticated session (below).

Don't interpret this as the service being broken — it is usually working
correctly and being refused upstream.

### `422` mentioning ffmpeg or tesseract not installed

The image is built wrong or was replaced. Both come from `apt` in the
`Dockerfile`. Rebuild:

```bash
docker compose up -d --build
docker compose exec insta-parser ffmpeg -version
docker compose exec insta-parser tesseract --version
```

### `422` "call /download first" / "call /extract-frames first"

Not a service fault — the caller ran steps out of order, or the job's files
were already cleaned up. Restart the sequence from `/download`.

### Transcription is very slow

Expected on CPU. To trade accuracy for speed, drop the model size:

```yaml
WHISPER_MODEL: "tiny"    # from the default "base"
```

Then `docker compose up -d`. Sizes: `tiny` < `base` < `small` < `medium`.
Only one transcription runs at a time (`TRANSCRIBE_CONCURRENCY`); raising it
on a CPU-only box usually makes everything slower, not faster.

### First request after a rebuild is slow

The whisper model downloads on first use. It is cached on the data volume
(`HF_HOME=/data/.cache/huggingface`), so this is a one-time cost that survives
container recreation — but not `docker compose down -v`, which deletes the
volume.

### Jobs vanish / polling returns 404

Job state is in memory. A restart clears it, and finished records are evicted
after `JOB_TTL_HOURS`. Re-submit the URL. If you need results to outlive a
restart, have the caller persist them when it collects them.

### Disk filling up

`/process` cleans up after itself, but per-step jobs leave files until deleted
or swept.

```bash
docker system df -v | grep insta-parser_data          # volume size
docker compose exec insta-parser du -sh /data/*       # per-job usage
docker compose exec insta-parser ls /data             # job folders
```

Fixes: have callers `DELETE /jobs/{job_id}`; lower `JOB_TTL_HOURS`; confirm
`KEEP_FILES` is not left at `true`. To force an immediate sweep, restart the
container — it sweeps on startup.

## Authenticated Instagram session

The durable fix for rate limiting. Generate the session on a trusted machine —
it is a credential, so do not commit it or bake it into the image.

```bash
pip install instaloader
instaloader --login=<username>
# writes ~/.config/instaloader/session-<username>
```

Copy it onto the data volume and point the service at it:

```bash
docker compose cp ~/.config/instaloader/session-<username> \
  insta-parser:/data/session-<username>
```

```yaml
environment:
    IG_USERNAME: "<username>"
    IG_SESSION_FILE: "/data/session-<username>"
```

`docker compose up -d`, then confirm in the logs:

```
INFO insta_parser: Loaded Instagram session for <username>
```

If the session is invalid the service logs a warning and **continues
anonymously** rather than failing — so if `502`s persist after configuring
this, check for that warning; a silent fallback looks identical to a broken
session from the outside. Sessions expire; regenerate when they do.

## Tuning reference

Set in `docker-compose.yaml` under `environment:`, then `docker compose up -d`.

| Var | Default | Raise/lower when |
|---|---|---|
| `WHISPER_MODEL` | `base` | `tiny` for speed, `small`/`medium` for accuracy |
| `WHISPER_DEVICE` | `cpu` | `cuda` only with a GPU passed into the container |
| `WHISPER_COMPUTE_TYPE` | `int8` | `float16` on GPU; `int8` is right for CPU |
| `TRANSCRIBE_CONCURRENCY` | `1` | Only raise with cores to spare |
| `JOB_TTL_HOURS` | `24` | Lower if disk is tight |
| `KEEP_FILES` | `false` | `true` only while debugging a specific job |
| `MAX_FRAMES` | `60` | Raise for long reels, lower to speed up OCR |
| `FRAME_SCALE_HEIGHT` | `720` | Raise if OCR misses small text, lower for speed |
| `SCENE_THRESHOLD` | `0.3` | Raise for fewer frames, lower to catch subtler cuts |
| `OCR_DEDUPE_THRESHOLD` | `90` | Lower to drop more near-duplicate text |
| `FFMPEG_TIMEOUT` | `300` | Raise only if long videos legitimately time out |
| `WORK_DIR` | `/data` | Leave alone — must stay on the mounted volume |
| `LOG_LEVEL` | `INFO` | `DEBUG` when diagnosing |

## Debugging one specific job

Set `KEEP_FILES: "true"`, re-run the job, then inspect what it produced:

```bash
docker compose exec insta-parser ls -la /data/<job_id>
docker compose exec insta-parser ls /data/<job_id>/frames
docker compose exec insta-parser cat /data/<job_id>/transcript.json
```

Each step writes its output there (`video.mp4`, `audio.mp3`, `frames/`,
`metadata.json`, `transcript.json`, `ocr.json`), so you can see exactly which
stage produced bad data. **Set `KEEP_FILES` back to `false` afterwards** —
left on, it grows the volume with every job.

## Security note

The service has **no authentication**. It is deliberately not exposed through
`tailscale-serve.sh` and should stay on the local bridge, reachable only from
the homelab host and its containers. Don't publish it to the tailnet or the
internet without putting auth in front of it.
