#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if systemctl is-enabled docker-cleanup.timer >/dev/null 2>&1; then
    echo "[WARN] docker-cleanup.timer already installed."
    exit 0
fi

echo "[INFO] Setting up weekly Docker cleanup timer..."

sudo tee /etc/systemd/system/docker-cleanup.service > /dev/null <<'EOF'
[Unit]
Description=Docker resource cleanup (containers, images, networks, build cache)

[Service]
Type=oneshot
ExecStart=/usr/bin/docker system prune -f
EOF

sudo tee /etc/systemd/system/docker-cleanup.timer > /dev/null <<'EOF'
[Unit]
Description=Weekly Docker cleanup

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now docker-cleanup.timer

echo "[OK] docker-cleanup.timer enabled. Next run: $(systemctl show docker-cleanup.timer --property=NextElapseUSecRealtime --value)"
