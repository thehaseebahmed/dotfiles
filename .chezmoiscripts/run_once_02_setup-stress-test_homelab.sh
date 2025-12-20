#!/usr/bin/env bash
set -e

echo "[+] Ensuring stress-ng and htop are installed..."

# Install only if missing
if ! command -v stress-ng >/dev/null 2>&1 || ! command -v btop >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y stress-ng btop
else
    echo "    Packages already installed."
fi

SERVICE_FILE="/etc/systemd/system/stress-weekly.service"
TIMER_FILE="/etc/systemd/system/stress-weekly.timer"
SCRIPT_FILE="/usr/local/bin/run-stress-test.sh"

echo "[+] Ensuring stress test script exists..."
if [ ! -f "$SCRIPT_FILE" ]; then
    sudo tee "$SCRIPT_FILE" >/dev/null <<'EOF'
#!/usr/bin/env bash
# Simple CPU + I/O stress test for 2 minutes

echo "[+] Starting stress test at $(date)"

# CPU + I/O + memory torture for 2 minutes
stress-ng --cpu 4 --cpu-load 80 --io 2 --vm 1 --vm-bytes 512M --timeout 360s

echo "[+] Stress test completed at $(date)"
EOF
    sudo chmod +x "$SCRIPT_FILE"
else
    echo "    Script already exists."
fi

echo "[+] Ensuring systemd service exists..."
if [ ! -f "$SERVICE_FILE" ]; then
    sudo tee "$SERVICE_FILE" >/dev/null <<'EOF'
[Unit]
Description=Weekly random stress test

[Service]
Type=oneshot
ExecStart=/usr/local/bin/run-stress-test.sh
EOF
else
    echo "    Service already exists."
fi

echo "[+] Ensuring systemd timer exists..."
if [ ! -f "$TIMER_FILE" ]; then
    sudo tee "$TIMER_FILE" >/dev/null <<'EOF'
[Unit]
Description=Run stress test once a week at a random time

[Timer]
OnCalendar=weekly
RandomizedDelaySec=7d
Persistent=true

[Install]
WantedBy=timers.target
EOF
else
    echo "    Timer already exists."
fi

echo "[+] Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "[+] Enabling and starting timer (if not already enabled)..."
sudo systemctl enable --now stress-weekly.timer

echo "[+] Done. Timer status:"
systemctl status stress-weekly.timer --no-pager

