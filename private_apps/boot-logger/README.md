# Boot Logger

A systemd-based service that tracks system boots and detects abnormal shutdowns on homelab devices.

## Purpose

This service helps diagnose recurring restart issues by:
- Logging every system boot with timestamp and details
- Detecting abnormal shutdowns (crashes, power failures, kernel panics)
- Capturing error logs from the previous boot session
- Identifying thermal, power, or kernel issues

## How It Works

1. **Boot Logger Service** (`boot-logger.service`):
   - Runs at every system boot
   - Checks if the previous shutdown was clean
   - Logs boot information and system status
   - Analyzes previous boot logs for errors

2. **Shutdown Marker Service** (`boot-logger-shutdown.service`):
   - Runs before system shutdown/reboot
   - Creates a marker file indicating clean shutdown
   - If this marker is missing on next boot, indicates abnormal shutdown

3. **Detection Capabilities**:
   - Kernel panics and crashes
   - Thermal/overheating issues
   - Power failures
   - Unexpected reboots
   - System errors

## Installation

```bash
# Enable the service
~/apps/boot-logger/enable
```

This will:
- Install both systemd services
- Create the log file at `/var/log/boot-tracker.log`
- Enable services to run on boot and shutdown

## Usage

### View Logs
```bash
# Last 50 lines (default)
~/apps/boot-logger/logs

# Last 100 lines
~/apps/boot-logger/logs -n 100

# All logs
~/apps/boot-logger/logs --all

# Follow logs in real-time
~/apps/boot-logger/logs --follow
```

### Check Status
```bash
~/apps/boot-logger/status
```

Shows:
- Service status
- Recent boot events
- Last 30 log entries

### Disable Service
```bash
~/apps/boot-logger/disable
```

Disables and removes the services (preserves logs).

## Log Format

Each boot creates an entry like:

```
[2025-12-11 21:00:00] ═══════════════════════════════════════════════════════════
[2025-12-11 21:00:00] BOOT EVENT #42 on homelab-chromebox
[2025-12-11 21:00:00] ═══════════════════════════════════════════════════════════
[2025-12-11 21:00:00] Boot Time: 2025-12-11 21:00:00
[2025-12-11 21:00:00] Kernel: 6.12.48-1-MANJARO
[2025-12-11 21:00:00] Previous Shutdown: ABNORMAL/UNEXPECTED
[2025-12-11 21:00:00] ⚠️  WARNING: System did not shut down cleanly!
[2025-12-11 21:00:00] 🔥 KERNEL PANIC OR CRASH DETECTED in previous boot
[2025-12-11 21:00:00] Current Status:
[2025-12-11 21:00:00]   Uptime: up 5 minutes
[2025-12-11 21:00:00]   Load:  0.45, 0.32, 0.15
[2025-12-11 21:00:00]   CPU Temp: +45.0°C
[2025-12-11 21:00:00] ═══════════════════════════════════════════════════════════
```

## Troubleshooting

### Service not running
```bash
sudo systemctl status boot-logger.service
sudo journalctl -u boot-logger.service -n 50
```

### Logs not appearing
```bash
# Check if log file exists
ls -la /var/log/boot-tracker.log

# Check service execution
sudo journalctl -u boot-logger.service --since today
```

### Manual test
```bash
# Run the boot logger script manually
~/apps/boot-logger/boot-logger.sh

# Check the logs
~/apps/boot-logger/logs
```

## Integration with Chezmoi

This service is managed by chezmoi and will be deployed to homelab machines matching the hostname pattern `homelab-*`.

The service files are stored in:
- `~/.local/share/chezmoi/private_apps/boot-logger/`

After chezmoi changes:
```bash
chezmoi apply
cd ~/apps/boot-logger
./enable
```

## Files

- `boot-logger.sh` - Main boot tracking script
- `shutdown-marker.sh` - Creates clean shutdown marker
- `boot-logger.service` - Systemd service for boot tracking
- `boot-logger-shutdown.service` - Systemd service for shutdown marker
- `enable` - Install and enable services
- `disable` - Disable and remove services
- `status` - Check service status
- `logs` - View boot logs

## Log Location

All boot events are logged to: `/var/log/boot-tracker.log`

This file persists across reboots and should be monitored for patterns of abnormal shutdowns.
