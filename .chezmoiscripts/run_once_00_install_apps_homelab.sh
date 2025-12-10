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

install_portainer_agent() {
    if sudo docker ps -a --format "{{.Names}}" | grep -q "^portainer_agent$" 2>/dev/null; then
        warn "portainer_agent container already exists."
        return 0
    fi

    if ! eval "command -v docker >/dev/null 2>&1"; then
        error "docker is not installed. Install docker first."
        return 1
    fi

    info "Installing portainer agent..."

    # Deploy Portainer Agent with podman
    # Port 9001: Agent communication port (must be accessible from Portainer Server)
    # Socket mount: Podman socket to Docker socket path (what Agent expects)
    # Volume mount: Podman volumes to Docker volumes path (what Agent expects)
    sudo docker run -d \
        -p 9001:9001 \
        --name portainer_agent \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /var/lib/docker/volumes:/var/lib/docker/volumes \
        -v /:/host \
        portainer/agent:2.33.5

    ok "portainer agent installed and running on port 9001."
    info "Connect from Portainer Server using this host's IP:9001"
}

# Output Helpers
info()  { echo "[INFO] $1"; }
warn()  { echo "[WARN] $1"; }
error() { echo "[ERROR] $1"; }
ok()    { echo "[OK] $1"; }

main "$@"
