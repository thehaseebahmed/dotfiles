FROM nousresearch/hermes-agent:v2026.7.20

RUN apt-get update && apt-get install -y --no-install-recommends \
    bsdextrautils \
    jq \
    gpg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# JIRA CLI
RUN apt-get update && apt-get install -y wget gnupg
RUN mkdir -p -m 755 /etc/apt/keyrings
RUN wget -nv -O- https://acli.atlassian.com/gpg/public-key.asc | gpg --dearmor -o /etc/apt/keyrings/acli-archive-keyring.gpg
RUN chmod go+r /etc/apt/keyrings/acli-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/acli-archive-keyring.gpg] https://acli.atlassian.com/linux/deb stable main" | tee /etc/apt/sources.list.d/acli.list > /dev/null
RUN apt-get update && apt-get install -y acli

RUN npm install --location=global @actual-app/cli

RUN VIRTUAL_ENV=/opt/hermes/.venv uv pip install "git+https://github.com/thehaseebahmed/bunq-cli"
RUN VIRTUAL_ENV=/opt/hermes/.venv uv pip install instaloader
RUN VIRTUAL_ENV=/opt/hermes/.venv uv tool install okflint
