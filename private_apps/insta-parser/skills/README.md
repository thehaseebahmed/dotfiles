# insta-parser agent skills

Portable skill documents describing how to use and operate the `insta-parser`
service. They're plain Markdown with YAML frontmatter (`name`, `description`),
which is the common agent-skill convention — no tooling or vendor lock-in, and
readable as ordinary docs.

| Skill | Use for |
|---|---|
| `insta-parser-api/SKILL.md` | Calling the service: endpoints, the async polling flow, interpreting output, error handling |
| `insta-parser-ops/SKILL.md` | Running the container: rate limiting, ffmpeg/tesseract failures, slow transcription, disk usage, session login |

They live with the app so they deploy alongside it — chezmoi applies
`private_apps/` to `~/apps/` on homelab machines, putting these at
`~/apps/insta-parser/skills/`.

## Loading them

**Claude Code** — symlink or copy into a skills directory:

```bash
mkdir -p ~/.claude/skills
ln -s ~/apps/insta-parser/skills/insta-parser-api ~/.claude/skills/
ln -s ~/apps/insta-parser/skills/insta-parser-ops ~/.claude/skills/
```

**n8n AI Agent node** — paste the API skill's body into the system prompt, or
serve it as a text resource the agent can fetch. The ops skill is generally
not useful to a workflow agent; it's for whoever is fixing the container.

**Any other agent** — the frontmatter `description` says when the skill
applies and the body says how. Load it however that agent takes context.

## Keeping them accurate

These describe a real running service. If you change the API surface, error
codes, or env vars in `../app/` or `../docker-compose.yaml`, update the
matching skill in the same commit — a stale skill is worse than none, because
an agent will follow it confidently.
