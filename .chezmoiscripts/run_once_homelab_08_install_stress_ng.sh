#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if eval "{ command -v stress-ng } >/dev/null 2>&1"; then
    echo "[WARN] stress-ng already installed."
    return 0
fi

echo "[INFO] Installing stress-ng..."

sudo apt update
sudo apt install -y stress-ng

echo "[OK] stress-ng is installed."