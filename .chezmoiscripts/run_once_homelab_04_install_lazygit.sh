#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if eval "{ command -v lazygit } >/dev/null 2>&1"; then
    echo "[WARN] lazygit installed."
    return 0
fi

echo "[INFO] Installing lazygit..."

VERSION=$(sed 's/\..*//' /etc/debian_version)
if $VERSION gt 12; then
    sudo apt update
    sudo apt install -y lazygit
else
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin/
fi

echo "[OK] lazygit installed."