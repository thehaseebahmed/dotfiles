# insta-parser

Deployed here purely as a `docker-compose.yaml` pulling the published image
from `ghcr.io/thehaseebahmed/insta-parser`. Source, the FastAPI app, the CLI,
API docs, and agent skill docs all live in
[thehaseebahmed/insta-parser](https://github.com/thehaseebahmed/insta-parser) —
this directory is deployment config only.

Listens on host port `8420` (container port `8000`), data volume at
`~/volumes/insta-parser/data`. See the upstream repo's README for the full
env var reference, API, and CLI usage.

Bump the `image:` tag in `docker-compose.yaml` to move to a newer release —
Renovate tracks it the same way it does other pinned images in this repo.
