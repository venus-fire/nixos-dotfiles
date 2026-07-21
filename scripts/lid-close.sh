#!/usr/bin/env bash
# Check AC power status; if discharging (on battery), lock and suspend.
# Otherwise just lock the screen.
set -euo pipefail

# Determine if on battery: check all power supplies for discharging status
if grep -q "Discharging" /sys/class/power_supply/*/status 2>/dev/null; then
    noctalia msg session lock-and-suspend
else
    noctalia msg session lock
fi
