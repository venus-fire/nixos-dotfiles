#!/usr/bin/env bash
# =============================================================================
# meshchatx-update.sh — update MeshChatX to the latest release wheel
# =============================================================================
# Re-installs the newest release wheel from Quad4-Software/MeshChatX into the
# MeshChatX venv, then restarts the systemd service if it's running and you
# have root. Installed to PATH as `meshchatx-update` by modules/meshchatx.nix.
#
# Usage:
#   meshchatx-update                          # update to latest release
#   MESHCHATX_VENV=/path/to/venv meshchatx-update   # override venv path
# =============================================================================

set -euo pipefail

VENV="${MESHCHATX_VENV:-/home/venus/.local/share/meshchatx-venv}"
REPO="Quad4-Software/MeshChatX"

if [ ! -x "$VENV/bin/meshchat" ]; then
  echo "error: $VENV/bin/meshchat not found — create the venv first (the meshchatx systemd service bootstraps it)" >&2
  exit 1
fi

TAG=$(curl -sf "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -oE '"tag_name": *"v[^"]+"' | head -1 | cut -d'"' -f4)

if [ -z "$TAG" ]; then
  echo "error: could not determine latest release tag from GitHub API" >&2
  exit 1
fi

URL="https://github.com/${REPO}/releases/download/${TAG}/reticulum_meshchatx-${TAG#v}-py3-none-any.whl"

echo "current: $("$VENV/bin/pip" show reticulum-meshchatx 2>/dev/null | grep -i '^Version:' | cut -d' ' -f2 || echo 'not installed')"
echo "updating to: ${TAG}"
"$VENV/bin/pip" install --force-reinstall --quiet "$URL"

echo "installed: $("$VENV/bin/pip" show reticulum-meshchatx | grep -i '^Version:' | cut -d' ' -f2)"

if systemctl is-active meshchatx >/dev/null 2>&1; then
  if [ "$(id -u)" = "0" ]; then
    systemctl restart meshchatx
    echo "restarted meshchatx service"
  else
    echo "service is running — restart it with: sudo systemctl restart meshchatx"
  fi
fi
