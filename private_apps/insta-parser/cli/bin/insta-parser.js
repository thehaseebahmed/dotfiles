#!/usr/bin/env node
"use strict";

// Minimal CLI wrapper over the insta-parser HTTP API (see ../../README.md and
// ../../skills/insta-parser-api/SKILL.md for the API itself). Deliberately
// dependency-free: one file, Node's built-in fetch, no argument-parsing
// library — this only needs to cover `job start/status/wait/delete` and
// `health`.

const USAGE = `insta-parser - CLI for the self-hosted insta-parser API

Usage:
  insta-parser job start <url>              Queue the full pipeline for a reel/post URL
  insta-parser job status <job_id>          Get the current status/result of a job
  insta-parser job wait <job_id> [options]  Poll a job until status is done or error
  insta-parser job delete <job_id>          Delete a job's files
  insta-parser health                       Check the service is reachable

Options:
  --base-url <url>      insta-parser base URL (default: $INSTA_PARSER_URL or http://localhost:8420)
  --interval <seconds>  job wait: poll interval, default 7
  --timeout <seconds>   job wait: give up after this long, default 600
  -h, --help             Show this help

Examples:
  insta-parser job start "https://www.instagram.com/reel/ABC123xyz/"
  insta-parser job status 3f1c9a2b...
  insta-parser job wait 3f1c9a2b... --interval 5 --timeout 300
  insta-parser job delete 3f1c9a2b...

Env:
  INSTA_PARSER_URL      Default base URL, e.g. http://172.17.0.1:8420 or a Tailscale host

Output is always JSON on stdout. On failure, {"error": "..."} is written to
stderr and the process exits non-zero — including when 'job wait' reaches a
terminal status of "error" (the job's own result is still printed to stdout).
`;

class CliError extends Error {}

function parseArgs(argv) {
  const positional = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "-h" || arg === "--help") {
      flags.help = true;
    } else if (arg === "--base-url") {
      flags.baseUrl = argv[++i];
    } else if (arg === "--interval") {
      flags.interval = argv[++i];
    } else if (arg === "--timeout") {
      flags.timeout = argv[++i];
    } else if (arg.startsWith("--")) {
      throw new CliError(`Unknown option: ${arg}`);
    } else {
      positional.push(arg);
    }
  }
  return { positional, flags };
}

function baseUrlFrom(flags) {
  const url = flags.baseUrl || process.env.INSTA_PARSER_URL || "http://localhost:8420";
  return url.replace(/\/+$/, "");
}

async function request(method, baseUrl, path, body) {
  let response;
  try {
    response = await fetch(`${baseUrl}${path}`, {
      method,
      headers: body ? { "Content-Type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (exc) {
    throw new CliError(
      `Could not reach insta-parser at ${baseUrl} (${exc.message}). ` +
        "Is INSTA_PARSER_URL / --base-url correct, and is the service reachable from here?"
    );
  }

  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    payload = text;
  }

  if (!response.ok) {
    const detail = payload && typeof payload === "object" && "detail" in payload ? payload.detail : text;
    throw new CliError(`insta-parser returned ${response.status}: ${detail}`);
  }
  return payload;
}

function printJson(value) {
  process.stdout.write(JSON.stringify(value, null, 2) + "\n");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function positiveNumber(value, fallback, flagName) {
  if (value === undefined) return fallback;
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) {
    throw new CliError(`${flagName} must be a positive number of seconds, got ${JSON.stringify(value)}`);
  }
  return n;
}

async function jobStart(baseUrl, url) {
  if (!url) {
    throw new CliError('job start requires a URL, e.g. insta-parser job start "https://www.instagram.com/reel/ABC123xyz/"');
  }
  return request("POST", baseUrl, "/process", { url });
}

async function jobStatus(baseUrl, jobId) {
  if (!jobId) throw new CliError("job status requires a job_id");
  return request("GET", baseUrl, `/jobs/${encodeURIComponent(jobId)}`);
}

async function jobDelete(baseUrl, jobId) {
  if (!jobId) throw new CliError("job delete requires a job_id");
  return request("DELETE", baseUrl, `/jobs/${encodeURIComponent(jobId)}`);
}

async function jobWait(baseUrl, jobId, flags) {
  if (!jobId) throw new CliError("job wait requires a job_id");
  // Defaults follow the polling guidance in skills/insta-parser-api/SKILL.md:
  // poll every 5-10s, give up after ~10 minutes.
  const intervalSec = positiveNumber(flags.interval, 7, "--interval");
  const timeoutSec = positiveNumber(flags.timeout, 600, "--timeout");

  const deadline = Date.now() + timeoutSec * 1000;
  for (;;) {
    const job = await jobStatus(baseUrl, jobId);
    if (job.status === "done" || job.status === "error") {
      return job;
    }
    if (Date.now() >= deadline) {
      throw new CliError(
        `Gave up waiting on job ${jobId} after ${timeoutSec}s (last status: ${job.status}, step: ${job.step}). ` +
          `The job may still be running - check again with 'insta-parser job status ${jobId}'.`
      );
    }
    await sleep(intervalSec * 1000);
  }
}

async function health(baseUrl) {
  return request("GET", baseUrl, "/health");
}

async function main() {
  const { positional, flags } = parseArgs(process.argv.slice(2));

  if (flags.help) {
    process.stdout.write(USAGE);
    return;
  }
  if (positional.length === 0) {
    process.stderr.write(USAGE);
    process.exitCode = 1;
    return;
  }

  const baseUrl = baseUrlFrom(flags);
  const [group, action, jobArg] = positional;

  let result;
  if (group === "job") {
    if (action === "start") result = await jobStart(baseUrl, jobArg);
    else if (action === "status") result = await jobStatus(baseUrl, jobArg);
    else if (action === "delete") result = await jobDelete(baseUrl, jobArg);
    else if (action === "wait") result = await jobWait(baseUrl, jobArg, flags);
    else throw new CliError(`Unknown 'job' action: ${action ?? "(none)"}. Expected start, status, wait, or delete.`);
  } else if (group === "health") {
    result = await health(baseUrl);
  } else {
    throw new CliError(`Unknown command: ${group}. Run 'insta-parser --help' for usage.`);
  }

  printJson(result);
  if (group === "job" && action === "wait" && result.status === "error") {
    process.exitCode = 1;
  }
}

main().catch((exc) => {
  const message = exc instanceof CliError ? exc.message : `Unexpected error: ${exc.stack || exc.message}`;
  process.stderr.write(JSON.stringify({ error: message }, null, 2) + "\n");
  process.exitCode = 1;
});
