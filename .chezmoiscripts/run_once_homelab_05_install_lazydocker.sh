#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if command -v lazydocker >/dev/null 2>&1; then
    echo "[WARN] lazydocker installed."
    exit 0
fi

echo "[INFO] Installing lazydocker..."
curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
echo "[OK] lazydocker installed."