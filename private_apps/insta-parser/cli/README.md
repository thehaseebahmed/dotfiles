# insta-parser CLI

A minimal, dependency-free CLI over the [insta-parser API](../README.md) —
one file (`bin/insta-parser.js`), Node's built-in `fetch`, no npm packages to
install. Built so an agent (or a shell script) can drive the service without
hand-writing `curl` calls or polling loops.

**Not published to npm.** "Local only" — run it from a clone of this repo.

## Setup

```bash
cd private_apps/insta-parser/cli
npm link          # puts `insta-parser` on your PATH, backed by this checkout
```

Or run it straight from the repo without installing anything:

```bash
node private_apps/insta-parser/cli/bin/insta-parser.js job start "https://www.instagram.com/reel/ABC123xyz/"
```

Or via `npx` against the local path (no install, no PATH changes):

```bash
npx -y ./private_apps/insta-parser/cli job start "https://www.instagram.com/reel/ABC123xyz/"
```

(The `npx -y insta-parser ...` form only works if you've `npm link`ed it, or
inside `private_apps/insta-parser/cli` where `npx -y .` resolves to `.`. It
does **not** pull anything from the public npm registry — nothing is
published there.)

## Configuring the target service

insta-parser has no auth and no fixed public address — it's a homelab
container. The CLI needs to know where to reach it:

```bash
export INSTA_PARSER_URL=http://172.17.0.1:8420   # or a Tailscale/LAN address
insta-parser job start "https://www.instagram.com/reel/ABC123xyz/"
```

Or per-call with `--base-url`. If neither is set, it defaults to
`http://localhost:8420` (the "same host" case from the API skill doc). See
["Reaching the service"](../skills/insta-parser-api/SKILL.md#reaching-the-service)
for which address to use from where.

## Commands

```
insta-parser job start <url>              Queue the full pipeline for a reel/post URL
insta-parser job status <job_id>          Get the current status/result of a job
insta-parser job wait <job_id> [options]  Poll a job until status is done or error
insta-parser job delete <job_id>          Delete a job's files
insta-parser health                       Check the service is reachable
```

Options:

| Flag | Applies to | Default |
|---|---|---|
| `--base-url <url>` | all | `$INSTA_PARSER_URL` or `http://localhost:8420` |
| `--interval <seconds>` | `job wait` | `7` |
| `--timeout <seconds>` | `job wait` | `600` (~10 min, per the API skill's polling guidance) |

## Output and exit codes

Every command prints JSON to stdout on success. On failure — an unreachable
host, a non-2xx response, bad arguments — it prints `{"error": "..."}` to
stderr and exits non-zero, so scripts can branch on the exit code rather than
parsing stdout.

`job wait` is the one command where success/failure of the *CLI call* and
success/failure of the *job* can diverge: if the job reaches `status: "done"`
or `status: "error"`, `job wait` prints that job object to stdout either way
(a job that failed is still a completed poll), but exits `1` when the job's
own status is `"error"` — so `insta-parser job wait $ID && echo ok` behaves
the way you'd expect. A genuine CLI failure (timeout waiting for a terminal
status, network error) prints `{"error": "..."}` to stderr instead, same as
every other command.

## Example: full pipeline in a shell script

```bash
#!/usr/bin/env bash
set -euo pipefail
export INSTA_PARSER_URL=http://172.17.0.1:8420

job_id=$(insta-parser job start "$1" | jq -r .job_id)
insta-parser job wait "$job_id" > result.json
insta-parser job delete "$job_id" > /dev/null
jq '.result.metadata.places' result.json
```

## What this doesn't cover

Only the `/process` + `/jobs/{job_id}` path is wrapped — that's the
documented "normal case" in the API skill. The per-step endpoints
(`/download`, `/extract-audio`, `/transcribe`, `/extract-frames`, `/ocr`,
`/extract-places`) aren't exposed here; use `curl` directly for those (see
the main [README](../README.md#step-by-step-synchronous)).
