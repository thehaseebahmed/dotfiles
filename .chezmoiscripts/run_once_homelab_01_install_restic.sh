#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if command -v restic >/dev/null 2>&1; then
    echo "[WARN] restic already installed."
    exit 0
fi

echo "[INFO] Installing restic..."

# Download latest restic binary
restic_version="0.17.3"
arch="amd64"

wget -O /tmp/restic.bz2 "https://github.com/restic/restic/releases/download/v${restic_version}/restic_${restic_version}_linux_${arch}.bz2"

# Extract and install
bunzip2 /tmp/restic.bz2
sudo mv /tmp/restic /usr/local/bin/
sudo chmod +x /usr/local/bin/restic

echo "[OK] restic installed."