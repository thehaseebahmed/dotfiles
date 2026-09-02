FROM docker.litellm.ai/berriai/litellm-database:latest

# npx (via nodejs-npm) and uvx (via uv), for MCP servers that are launched
# with `npx <pkg>` / `uvx <pkg>` from the LiteLLM proxy.
RUN apk update && \
    apk add --no-cache npm git curl && \
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh && \
    apk del curl && \
    rm -rf /var/cache/apk/*

# npm 12 defaults to allow-git=none, which blocks `npx github:org/repo#ref`
# style MCP servers (EALLOWGIT). MCP server refs here are user-registered
# and not tied to a package.json, so "root" doesn't help — allow git fetches
# outright. LiteLLM spawns MCP stdio subprocesses with a stripped env
# (litellm/experimental_mcp_client/client.py _get_safe_stdio_env), so an
# ENV var here doesn't reach npx — it has to live in npm's global config file.
RUN echo "allow-git=all" >> /etc/npmrc
