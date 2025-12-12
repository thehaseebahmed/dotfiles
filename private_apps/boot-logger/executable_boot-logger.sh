#!/bin/bash
# Boot Logger - Tracks system boots and detects abnormal shutdowns
set -euo pipefail

BOOT_LOG="/var/log/boot-tracker.log"
SHUTDOWN_MARKER="/var/run/boot-tracker-clean-shutdown"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$BOOT_LOG"
}

check_previous_shutdown() {
    if [ ! -f "$SHUTDOWN_MARKER" ]; then
        return 1  # Abnormal shutdown
    fi
    return 0  # Clean shutdown
}

main() {
    # Ensure log file exists
    sudo touch "$BOOT_LOG"

    # Get boot info
    BOOT_TIME=$(uptime -s)
    BOOT_COUNT=$(journalctl --list-boots | wc -l)
    KERNEL_VERSION=$(uname -r)
    HOSTNAME=$(hostname)

    # Check if previous shutdown was clean
    if check_previous_shutdown; then
        SHUTDOWN_STATUS="CLEAN"
        sudo rm -f "$SHUTDOWN_MARKER"
    else
        SHUTDOWN_STATUS="ABNORMAL/UNEXPECTED"
    fi

    # Get last shutdown time from journalctl
    LAST_SHUTDOWN=$(journalctl -b -1 -u systemd-shutdownd.service --no-pager 2>/dev/null | tail -n 1 || echo "Unknown")

    # Log boot event
    log_message "═══════════════════════════════════════════════════════════"
    log_message "BOOT EVENT #$BOOT_COUNT on $HOSTNAME"
    log_message "═══════════════════════════════════════════════════════════"
    log_message "Boot Time: $BOOT_TIME"
    log_message "Kernel: $KERNEL_VERSION"
    log_message "Previous Shutdown: $SHUTDOWN_STATUS"

    if [ "$SHUTDOWN_STATUS" = "ABNORMAL/UNEXPECTED" ]; then
        log_message "⚠️  WARNING: System did not shut down cleanly!"

        # Try to get crash info from previous boot
        PREV_BOOT_ERRORS=$(journalctl -b -1 -p err --no-pager 2>/dev/null | tail -n 10 || echo "No error logs available")
        if [ -n "$PREV_BOOT_ERRORS" ] && [ "$PREV_BOOT_ERRORS" != "No error logs available" ]; then
            log_message "Last errors from previous boot:"
            echo "$PREV_BOOT_ERRORS" | while read -r line; do
                log_message "  $line"
            done
        fi

        # Check for kernel panic
        PANIC_LINES=$(journalctl -b -1 -k --no-pager 2>/dev/null | grep -i "panic\|oops\|segfault" || true)
        if [ -n "$PANIC_LINES" ]; then
            log_message "🔥 KERNEL PANIC OR CRASH DETECTED in previous boot"
            log_message "Matching lines:"
            echo "$PANIC_LINES" | while read -r line; do
                log_message "  $line"
            done
        fi

        # Check for overheating
        THERMAL_LINES=$(journalctl -b -1 -k --no-pager 2>/dev/null | grep -i "thermal\|temperature\|overheat" || true)
        if [ -n "$THERMAL_LINES" ]; then
            log_message "🌡️  THERMAL ISSUES detected in previous boot"
            log_message "Matching lines:"
            echo "$THERMAL_LINES" | while read -r line; do
                log_message "  $line"
            done
        fi

        # Check for power issues
        POWER_LINES=$(journalctl -b -1 --no-pager 2>/dev/null | grep -i "power\|battery\|acpi" | grep -i "critical\|fail\|error" || true)
        if [ -n "$POWER_LINES" ]; then
            log_message "⚡ POWER ISSUES detected in previous boot"
            log_message "Matching lines:"
            echo "$POWER_LINES" | while read -r line; do
                log_message "  $line"
            done
        fi
    fi

    # Get current system info
    UPTIME=$(uptime -p)
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    TEMP=$(sensors 2>/dev/null | grep -i "core 0" | awk '{print $3}' || echo "N/A")

    log_message "Current Status:"
    log_message "  Uptime: $UPTIME"
    log_message "  Load: $LOAD"
    log_message "  CPU Temp: $TEMP"
    log_message "═══════════════════════════════════════════════════════════"
    log_message ""

    # Send notification if abnormal shutdown (optional - requires notify-send or similar)
    if [ "$SHUTDOWN_STATUS" = "ABNORMAL/UNEXPECTED" ]; then
        echo "Abnormal shutdown detected on $HOSTNAME at $BOOT_TIME" | \
            logger -t boot-tracker -p user.warning
    fi
}

main "$@"
