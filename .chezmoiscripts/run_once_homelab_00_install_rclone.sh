#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if eval "command -v rclone >/dev/null 2>&1"; then
    echo "[WARN] rclone already installed."
    return 0
fi

echo "[INFO] Installing rclone..."

# Download latest binary
sudo -v ; curl https://rclone.org/install.sh | sudo bash

echo "[OK] rclone installed."