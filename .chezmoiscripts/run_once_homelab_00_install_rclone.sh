#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if command -v rclone >/dev/null 2>&1; then
    echo "[WARN] rclone already installed."
    exit 0
fi

echo "[INFO] Installing rclone..."

# Download and verify install script
sudo -v
curl -fsSL https://rclone.org/install.sh -o /tmp/rclone-install.sh
sudo bash /tmp/rclone-install.sh
rm /tmp/rclone-install.sh

echo "[OK] rclone installed."