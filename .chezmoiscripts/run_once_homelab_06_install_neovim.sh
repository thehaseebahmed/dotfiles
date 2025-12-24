#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if eval "{ command -v nvim } >/dev/null 2>&1"; then
    echo "[WARN] neovim installed."
return 0
fi

echo "[INFO] Installing neovim..."

sudo apt update
sudo apt install -y gh neovim

echo "[OK] dev tools are installed."