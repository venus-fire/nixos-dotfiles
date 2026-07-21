#!/usr/bin/env bash
# Called by udev when AC power is removed.
# If the lid is closed, suspend the system.
set -uo pipefail

LID_STATE=$(cat /proc/acpi/button/lid/LID0/state 2>/dev/null || echo "state:      open")

if echo "$LID_STATE" | grep -q "closed"; then
    exec systemctl suspend
fi
