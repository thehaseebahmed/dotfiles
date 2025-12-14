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
    install_tailscale
    install_docker

    info "Homelab setup complete."
}

install_minimal_dev_env() {
    if eval "command -v gh >/dev/null 2>&1"; then
        warn "minimal dev setup already done."
        return 0
    fi

    info "Starting minimal dev setup..."

    # Download latest binary
    sudo apt update
    sudo apt install gh lazygit nvim

    ok "Minimal dev setup is done."
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

install_tailscale() {
    if eval "command -v tailscale >/dev/null 2>&1"; then
        warn "tailscale already installed."
        return 0
    fi

    info "Installing tailscale..."

    curl -fsSL https://tailscale.com/install.sh | sh

    ok "tailscale installed."
}

install_docker() {
    if eval "command -v docker >/dev/null 2>&1"; then
        warn "docker already installed."
        return 0
    fi

    info "Installing Docker..."
    
    # Remove conflicting packages
    sudo apt-get update
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)

    # Add Docker's official GPG key:
    sudo apt update
    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update

    # Install docker packages
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    ok "Docker installed. Log out and back in for group changes to take effect."
}

# Output Helpers
info()  { echo "[INFO] $1"; }
warn()  { echo "[WARN] $1"; }
error() { echo "[ERROR] $1"; }
ok()    { echo "[OK] $1"; }

main "$@"
