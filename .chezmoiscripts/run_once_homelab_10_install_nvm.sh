#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if command -v nvm >/dev/null 2>&1; then
    echo "[WARN] nvm already installed."
    exit 0
fi

echo "[INFO] Installing nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
echo "[OK] nvm installed."
