#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if eval "{ command -v btop } >/dev/null 2>&1"; then
    echo "[WARN] btop already installed."
    return 0
fi

echo "[INFO] Installing btop..."

sudo apt update
sudo apt install -y btop

echo "[OK] btop installed."