#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

main() {
    local pwd=$(pwd)
    info "OS Detected: {{ .osid | quote }}"
    info "Hostname: {{ .chezmoi.hostname | quote }}"
    info "Execution Dir: $pwd"
    echo ""

    # Applications
    echo ""
    info "Setup Apps..."
    install_rclone
    install_restic

    info "Homelab setup complete."
}

install_rclone() {
    if eval "command -v rclone >/dev/null 2>&1"; then
        warn "rclone already installed."
        return 0
    fi

    info "Installing rclone..."

    # Download latest binary
    sudo -v ; curl https://rclone.org/install.sh | sudo bash

    ok "rclone installed."
}

install_restic() {
    if eval "command -v restic >/dev/null 2>&1"; then
        warn "restic already installed."
        return 0
    fi

    info "Installing restic..."

    # Download latest restic binary
    local restic_version="0.17.3"
    local arch="amd64"
    wget -O /tmp/restic.bz2 "https://github.com/restic/restic/releases/download/v${restic_version}/restic_${restic_version}_linux_${arch}.bz2"

    # Extract and install
    bunzip2 /tmp/restic.bz2
    sudo mv /tmp/restic /usr/local/bin/
    sudo chmod +x /usr/local/bin/restic

    # Clean up
    rm -f /tmp/restic.bz2

    ok "restic installed."
}

# Output Helpers
info()  { echo "[INFO] $1"; }
warn()  { echo "[WARN] $1"; }
error() { echo "[ERROR] $1"; }
ok()    { echo "[OK] $1"; }

main "$@"
