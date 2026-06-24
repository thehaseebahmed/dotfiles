#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

HERMESUSER="hermesuser"

if id "$HERMESUSER" >/dev/null 2>&1; then
    echo "[WARN] User $HERMESUSER already exists."
    exit 0
fi

echo "[INFO] Creating $HERMESUSER user..."

sudo useradd --create-home --shell /bin/bash --comment "Hermes agent user" "$HERMESUSER"

# Lock password — SSH key auth only
sudo passwd --lock "$HERMESUSER"

# Set up SSH directory for authorized_keys
sudo mkdir -p "/home/$HERMESUSER/.ssh"
sudo chmod 700 "/home/$HERMESUSER/.ssh"
sudo touch "/home/$HERMESUSER/.ssh/authorized_keys"
sudo chmod 600 "/home/$HERMESUSER/.ssh/authorized_keys"
sudo chown -R "$HERMESUSER:$HERMESUSER" "/home/$HERMESUSER/.ssh"

# Docker operations
sudo usermod -aG docker "$HERMESUSER"

# System log reads without sudo
sudo usermod -aG systemd-journal "$HERMESUSER"

# Read-only stat tools that need elevated permissions (I/O and network per-process monitoring)
sudo tee /etc/sudoers.d/hermesuser > /dev/null <<'EOF'
# hermesuser: read-only system monitoring only, no write/change permissions
hermesuser ALL=(ALL) NOPASSWD: /usr/bin/iotop, /usr/sbin/iotop, /usr/bin/nethogs, /usr/sbin/nethogs
EOF
sudo chmod 0440 /etc/sudoers.d/hermesuser

echo "[OK] $HERMESUSER created. Add SSH public key to /home/$HERMESUSER/.ssh/authorized_keys."
