#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if eval "command -v tailscale >/dev/null 2>&1"; then
    echo "[WARN] tailscale already installed."
    return 0
fi

echo "[INFO] Installing tailscale..."

curl -fsSL https://tailscale.com/install.sh | sh

echo "[OK] tailscale installed."