#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if command -v btop >/dev/null 2>&1; then
    echo "[WARN] btop already installed."
    exit 0
fi

echo "[INFO] Installing btop..."
sudo apt-get update
sudo apt-get install -y btop
echo "[OK] btop installed."