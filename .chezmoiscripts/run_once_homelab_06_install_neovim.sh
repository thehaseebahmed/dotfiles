#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if command -v nvim >/dev/null 2>&1; then
    echo "[WARN] neovim already installed."
    exit 0
fi

echo "[INFO] Installing neovim..."
sudo apt-get update
sudo apt-get install -y neovim
echo "[OK] neovim installed."