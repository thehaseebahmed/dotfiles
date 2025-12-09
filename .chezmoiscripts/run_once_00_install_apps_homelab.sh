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
    install_podman
    install_portainer_agent

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

install_tailscale() {
    if eval "command -v tailscale >/dev/null 2>&1"; then
        warn "tailscale already installed."
        return 0
    fi

    info "Installing tailscale..."

    curl -fsSL https://tailscale.com/install.sh | sh

    ok "tailscale installed."
}

install_podman() {
    if eval "command -v podman >/dev/null 2>&1"; then
        warn "podman already installed."
        return 0
    fi

    info "Installing podman..."

    # Install podman from official repositories (Debian 11+/Ubuntu 20.10+)
    sudo apt-get update
    sudo apt-get install -y podman

    ok "podman installed."
}

install_portainer_agent() {
    if podman ps -a --format "{{.Names}}" | grep -q "^portainer_agent$" 2>/dev/null; then
        warn "portainer_agent container already exists."
        return 0
    fi

    if ! eval "command -v podman >/dev/null 2>&1"; then
        error "podman is not installed. Install podman first."
        return 1
    fi

    info "Installing portainer agent..."

    # Deploy Portainer Agent with podman
    # Port 9001: Agent communication port (must be accessible from Portainer Server)
    # Socket mount: Podman socket to Docker socket path (what Agent expects)
    # Volume mount: Podman volumes to Docker volumes path (what Agent expects)
    podman run -d \
        -p 9001:9001 \
        --name portainer_agent \
        --restart=always \
        --privileged \
        -v /run/podman/podman.sock:/var/run/docker.sock \
        -v /var/lib/containers/storage/volumes:/var/lib/docker/volumes \
        portainer/agent:lts

    ok "portainer agent installed and running on port 9001."
    info "Connect from Portainer Server using this host's IP:9001"
}

# Output Helpers
info()  { echo "[INFO] $1"; }
warn()  { echo "[WARN] $1"; }
error() { echo "[ERROR] $1"; }
ok()    { echo "[OK] $1"; }

main "$@"
