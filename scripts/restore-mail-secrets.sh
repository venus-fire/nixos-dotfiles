#!/usr/bin/env bash
# =============================================================================
# scripts/restore-mail-secrets.sh — restore GPG key + pass store after a
# NixOS reinstall. Inverse of scripts/backup-mail-secrets.sh.
#
# USAGE
#   bash scripts/restore-mail-secrets.sh              # prompts for the path
#   bash scripts/restore-mail-secrets.sh <backup-dir> # or pass it directly
#
# WHAT IT DOES (order matters)
#   1. Locates the backup dir and validates all files are present.
#   2. Refuses to run if a pass store already exists (prevents clobbering a
#      newer/working setup — restore onto a FRESH install only).
#   3. Imports the GPG private key + sets ownertrust, THEN
#   4. extracts the pass store tarball (which carries the .gpg-id that binds
#      the store to the key — so no fingerprint juggling needed),
#   5. verifies decryption with `pass show`, then
#   6. verifies himalaya can read the inbox end-to-end.
#
# REQUIREMENTS
#   himalaya + pass + gpg must already be on PATH from the flake rebuild.
# =============================================================================

set -uo pipefail

# ---- 1. Resolve and validate the backup directory ---------------------------
BACKUP="${1:-}"
if [[ -z "${BACKUP}" ]]; then
  read -r -p "Path to the backup directory (from backup-mail-secrets.sh): " BACKUP
fi
BACKUP="${BACKUP/#\~/$HOME}"
BACKUP="${BACKUP%/}"
BACKUP="$(cd "$(dirname "$BACKUP")" 2>/dev/null && pwd 2>/dev/null)/$(basename "$BACKUP")"

[[ -d "${BACKUP}" ]] || { echo "error: not a directory: ${BACKUP}"; exit 1; }

TARBALL="$(ls "${BACKUP}"/password-store-*.tar.gz 2>/dev/null | head -1)"
req_files=( "mail-secrets.asc" "mail-secrets-private.asc" "ownertrust.txt" )
miss=0
for f in "${req_files[@]}"; do
  [[ -s "${BACKUP}/${f}" ]] || { echo "error: missing in backup: ${f}"; miss=1; }
done
[[ -n "${TARBALL}" ]] || { echo "error: no password-store-*.tar.gz found in backup"; miss=1; }
[[ $miss -eq 0 ]] || exit 1
echo "==> Backup validated: ${BACKUP}"

# ---- 2. Safety: refuse to clobber an existing store --------------------------
if [[ -d "${HOME}/.password-store" && -s "${HOME}/.password-store/.gpg-id" ]]; then
  echo "error: ~/.password-store already exists with a key bound." >&2
  echo "This script is for restoring onto a FRESH install." >&2
  echo "If you truly want to overwrite it, delete ~/.password-store first." >&2
  exit 1
fi

# ---- 3. Import GPG key + trust -------------------------------------------------
echo "==> Importing GPG private key"
if ! gpg --import "${BACKUP}/mail-secrets-private.asc"; then
  echo "error: GPG key import failed"; exit 1
fi
echo "==> Setting ownertrust"
gpg --import-ownertrust < "${BACKUP}/ownertrust.txt" 2>&1 \
  || { echo "error: ownertrust import failed (non-fatal, continuing)"; }

# ---- 4. Extract pass store -------------------------------------------------------
echo "==> Restoring pass store from $(basename "${TARBALL}")"
tar -C "${HOME}" -xzf "${TARBALL}" || { echo "error: store extract failed"; exit 1; }

# ---- 5. Verify decryption ----------------------------------------------------------
echo "==> Verifying pass store (decrypt check)"
MENT=0
for entry in google/app-password; do
  if pass show "${entry}" >/dev/null 2>&1; then
    echo "    OK: ${entry} decrypts"
  else
    echo "    FAIL: cannot decrypt ${entry}"; MENT=1
  fi
done
[[ $MENT -eq 0 ]] || { echo "error: decryption problem; do NOT send mail yet"; exit 1; }

# ---- 6. Verify himalaya end-to-end (non-destructive read) ---------------------------
echo "==> Testing himalaya inbox read"
if timeout 30 himalaya envelope list --page-size 3 >/dev/null 2>&1; then
  echo "    OK: himalaya read the inbox"
else
  echo "    WARNING: himalaya could not read the inbox (network/auth?) — "
  echo "    run 'himalaya envelope list --page-size 3' manually to inspect."
fi

echo
echo "Restore complete. Send a test email to confirm SMTP + save-to-Sent:"
echo "  printf 'From: <you>@gmail.com\\nTo: <you>@gmail.com\\nSubject: hi\\n\\ntest\\n' | himalaya template send"
