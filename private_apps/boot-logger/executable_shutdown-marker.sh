#!/bin/bash
# Shutdown Marker - Creates marker file on clean shutdown
set -euo pipefail

SHUTDOWN_MARKER="/var/run/boot-tracker-clean-shutdown"
BOOT_LOG="/var/log/boot-tracker.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$BOOT_LOG"
}

main() {
    # Create shutdown marker
    sudo touch "$SHUTDOWN_MARKER"

    # Log clean shutdown
    log_message "Clean shutdown initiated"
    log_message "Uptime was: $(uptime -p)"
}

main "$@"
