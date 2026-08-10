#!/usr/bin/env bash
# =============================================================================
# noctalia-backup.sh — snapshot noctalia's live Settings UI state into the repo
# =============================================================================
# Noctalia v5 keeps runtime settings (written by the Settings UI) in
# ~/.local/state/noctalia/settings.toml. That file is deliberately NOT
# symlinked into the repo (atomic temp+rename writes would replace the symlink
# with a real file), so this script snapshots the merged user config into the
# dotfiles repo:
#
#   config/noctalia/settings.toml
#
# Usage:
#   noctalia-backup                       # snapshot from the checkout
#   NOCTALIA_REPO=/path/to/repo noctalia-backup   # override repo location
#
# After running: git add config/noctalia/settings.toml && git commit
# =============================================================================

set -euo pipefail

REPO="${NOCTALIA_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [ ! -f "$REPO/flake.nix" ]; then
  echo "error: dotfiles repo not found (no flake.nix under $REPO)" >&2
  echo "hint: run from the checkout, or set NOCTALIA_REPO to the repo path" >&2
  exit 1
fi

OUT="$REPO/config/noctalia/settings.toml"
mkdir -p "$(dirname "$OUT")"

noctalia config export merged > "$OUT"

echo "snapshotted noctalia settings -> $OUT ($(wc -l < "$OUT") lines)"
echo "review:  noctalia config validate $OUT"
echo "commit:  git add config/noctalia/settings.toml && git commit -m 'update noctalia settings'"
