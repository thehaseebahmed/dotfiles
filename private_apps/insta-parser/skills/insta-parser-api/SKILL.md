---
name: insta-parser-api
description: Extract the caption, spoken transcript, and on-screen text from an Instagram reel or post using the self-hosted insta-parser HTTP service. Use when asked to summarize, read, transcribe, search, or pull the contents out of an Instagram reel/post URL, or when a workflow needs a reel's text as input.
---

# Using insta-parser

`insta-parser` is a small self-hosted HTTP service that turns an Instagram
reel/post URL into text: post metadata, a spoken-audio transcript, and OCR of
on-screen text. It is plain JSON over HTTP with no authentication and no SDK.

## Reaching the service

Default host port is **8420**.

| Caller | Base URL |
|---|---|
| Same host (shell, cron) | `http://localhost:8420` |
| Another container | `http://<homelab-host-ip>:8420` |
| Over Tailscale | `http://<homelab-host>:8420` |

**Container-to-container name lookup does not work here.** insta-parser runs
with `network_mode: bridge` (Docker's default `docker0` network), while most
other apps sit on their own compose networks. Docker only provides DNS between
containers on the *same user-defined* network, so `http://insta-parser:8000`
will fail to resolve from e.g. n8n. Use the host's IP with the published port
instead — `http://172.17.0.1:8420` (the `docker0` gateway, which is the host)
works from most containers, and the host's LAN or Tailscale address always
works.

Confirm reachability before anything else:

```bash
curl -s http://localhost:8420/health     # => {"status":"ok"}
```

**A CLI wrapper exists** at `../../cli/` (`insta-parser job start/status/wait/delete`,
`insta-parser health`) covering the `/process`+`/jobs` path below with
built-in polling (`job wait`) — see `cli/README.md`. It's not published to
npm; run it from a clone of this repo (`npm link` inside `cli/`, or
`node cli/bin/insta-parser.js ...` directly). Prefer it over hand-rolling
`curl` + a poll loop when working from a shell; use `curl` directly for the
per-step endpoints below, which the CLI doesn't cover.

## Decide which path to take

**Want everything (the normal case)?** Use `POST /process` and poll. It runs
the whole pipeline and returns metadata + transcript + OCR together.

**Only need one piece, or need to skip a step?** Use the per-step endpoints.
They share a `job_id` and must run in order — `/download` first, then
`/extract-audio` before `/transcribe`, and `/extract-frames` before `/ocr`.
Calling one out of order returns `422`.

Prefer `/process` unless you specifically need to skip work (e.g. a silent
reel where the transcript is worthless, or a talking-head reel with no
on-screen text worth OCR-ing).

## The full pipeline: POST /process

`/process` is **asynchronous**. It returns immediately with a `job_id`; you
poll for the result. Do not expect the result in the first response.

```bash
curl -sX POST http://localhost:8420/process \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://www.instagram.com/reel/ABC123xyz/"}'
```

```json
{ "job_id": "3f1c9a2b...", "status": "queued" }
```

Then poll until `status` is `done` or `error`:

```bash
curl -s http://localhost:8420/jobs/3f1c9a2b...
```

```json
{
  "job_id": "3f1c9a2b...",
  "status": "done",
  "step": null,
  "result": {
    "metadata": { "shortcode": "ABC123xyz", "username": "some_account", "caption": "...",
                  "timestamp": "2026-01-02T03:04:05", "like_count": 1234,
                  "comment_count": 56, "location": "Amsterdam",
                  "places": [ { "name": "Joe's Pizza", "city": "Rome", "country": "Italy",
                                "rating": 4.6, "maps_url": "https://maps.google.com/?cid=..." } ] },
    "transcript": { "text": "full transcript ...", "language": "en",
                    "segments": [ { "start": 0.0, "end": 1.5, "text": "..." } ] },
    "ocr_results": [ { "text": "ON SCREEN TEXT", "confidence": 92.4 } ]
  },
  "error": null,
  "updated_at": 1767322045.12
}
```

`updated_at` is a Unix timestamp of the last state change. If it stops
advancing while `status` is still `running`, the job is stuck on that step —
useful for deciding to give up rather than polling indefinitely.

**Polling guidance.** Transcription dominates the runtime. A short reel is
usually done in well under a minute, a long one can take several. Poll every
**5–10 seconds** and give up after ~10 minutes. While running, `step` tells
you where it is: `download` → `extract-audio` → `transcribe` →
`extract-frames` → `ocr`. Do not poll in a tight loop.

`status` values: `queued`, `running`, `done`, `error`, and `files-only` (a
folder exists from per-step calls but no `/process` run is tracking it).

## Per-step endpoints

All take `{"job_id": "..."}` except `/download`, which starts the job.

| Call | Returns |
|---|---|
| `POST /download` `{"url": "..."}` | `{job_id, metadata}` — metadata includes `video_path` |
| `POST /extract-audio` | `{job_id, audio_path}` |
| `POST /transcribe` | `{job_id, text, segments, language}` |
| `POST /extract-frames` | `{job_id, frames: [path, ...]}` |
| `POST /ocr` | `{job_id, results: [{frame, text, confidence}]}` |
| `POST /extract-places` | `{job_id, places: [{name, city, country, rating, maps_url}]}` |
| `DELETE /jobs/{job_id}` | `{job_id, status: "deleted"}` |

These are synchronous — each returns its result directly.

**Clean up when you're done.** Per-step jobs keep their files on disk.
Call `DELETE /jobs/{job_id}` at the end of a workflow. (A sweep eventually
removes folders older than the configured TTL, default 24h, but don't rely on
it.) `/process` cleans up after itself automatically.

## Interpreting the output

- **`username`** is the reel's owner. Falls back to `"Unknown"` if Instagram's
  API failed to return it (rare, but the video/transcript/OCR are unaffected).
- **`caption`** is the poster's own text. Often the single most informative
  field — check it before assuming you need the transcript.
- **`transcript.text`** is the spoken audio. Empty or gibberish means the reel
  had music only, or no speech. That is a normal result, not a failure.
- **`ocr_results`** is on-screen text, one entry per retained frame, already
  deduplicated across near-identical consecutive frames. `confidence` is a
  mean per-word Tesseract score (0–100); treat anything below ~60 as
  unreliable. Expect OCR noise from stylized fonts and busy backgrounds — do
  not present raw OCR as a verbatim quote.
- Reels often carry the same information in caption, speech, *and* on-screen
  text. When summarizing, reconcile the three rather than concatenating them.
- With default settings `/process` omits `video_path` and per-frame paths,
  because those files are deleted once the job completes.
- **`metadata.places`** is optional enrichment (a local model extracts place
  mentions, then Google Maps resolves them) — see the `insta-parser-ops`
  skill for how it's configured. If the service isn't configured for it,
  `places` is simply absent from `metadata`, not an error. If Maps
  resolution isn't configured but extraction is, entries still appear with
  `rating`/`maps_url` as `null`. Don't treat a missing/empty `places` as a
  sign the reel has no places in it — treat it as "not verified."

## Errors

| Code | Meaning | What to do |
|---|---|---|
| `400` | Bad input — URL isn't an Instagram post/reel, malformed `job_id`, or the post has no video | Fix the input. Don't retry as-is. |
| `404` | Unknown `job_id` | The job expired, was deleted, or the service restarted. Start over. |
| `422` | Step called out of order, or ffmpeg/tesseract failed | Run the prerequisite step. |
| `502` | Instagram fetch failed — rate-limited, private, or removed post | See below. |

The message is always in `detail`, e.g. `{"detail": "Could not find an
Instagram shortcode in URL: ..."}`. Read it before deciding what to do.

**On `502` (rate limiting).** Instagram throttles anonymous access. Do not
retry in a loop — that makes it worse. Back off for several minutes, and if it
persists report that the service likely needs an authenticated session
configured (`IG_USERNAME` / `IG_SESSION_FILE`) rather than continuing to retry.

**Job state is in memory.** If the container restarts, in-flight and completed
`/process` results are lost and polling returns `404`. Re-submit the URL.

## Constraints worth knowing

- Only **public** posts work unless the service is configured with a logged-in
  session. Private accounts return `502`.
- Only **video** posts (reels, video posts). A photo-only post returns `400`.
- One transcription runs at a time by default; concurrent requests queue rather
  than fail. Submitting many reels at once is safe but not faster.
- Frames are capped (default 60) and downscaled before OCR, so a very long
  reel's later scene changes may not be represented.
