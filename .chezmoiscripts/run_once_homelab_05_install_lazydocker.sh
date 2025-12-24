#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if eval "{ command -v lazydocker } >/dev/null 2>&1"; then
    echo "[WARN] lazydocker installed."
return 0
fi

echo "[INFO] Installing lazydocker..."

curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

echo "[OK] lazydocker installed."