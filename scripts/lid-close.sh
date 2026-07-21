#!/usr/bin/env bash
# Lock on lid close. On battery (discharging), also suspend.
# Uses upower for power-state detection.
# Logs to journal for debugging.
set -uo pipefail

log() {
    logger -t lid-close "$@"
}

battery=$(upower -e 2>/dev/null | grep -i bat || true)
log "lid closed: battery=$battery"

if [ -z "$battery" ]; then
    log "no battery found, lock only"
    exec noctalia msg session lock
fi

state=$(upower -i "$battery" 2>/dev/null | grep "state" | awk '{print $2}') || true
log "battery state=$state"

if [ "$state" = "discharging" ]; then
    log "on battery, lock-and-suspend"
    exec noctalia msg session lock-and-suspend
fi

log "on AC, lock only"
exec noctalia msg session lock
