#!/usr/bin/env bash
# Lock on lid close. On battery (discharging), also suspend.
# Uses upower for cleaner power-state detection.
set -euo pipefail

battery=$(upower -e 2>/dev/null | grep -i bat || true)
if [ -n "$battery" ]; then
    state=$(upower -i "$battery" 2>/dev/null | grep "state" | awk '{print $2}')
    if [ "$state" = "discharging" ]; then
        exec noctalia msg session lock-and-suspend
    fi
fi
exec noctalia msg session lock
