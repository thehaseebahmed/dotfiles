#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if command -v stress-ng >/dev/null 2>&1; then
    echo "[WARN] stress-ng already installed."
    exit 0
fi

echo "[INFO] Installing stress-ng..."
sudo apt-get update
sudo apt-get install -y stress-ng
echo "[OK] stress-ng is installed."