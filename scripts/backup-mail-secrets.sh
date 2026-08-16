#!/usr/bin/env bash
# =============================================================================
# scripts/backup-mail-secrets.sh — back up the GPG key + pass store needed to
# decrypt the himalaya Gmail app password across NixOS reinstalls.
#
# WHAT THIS IS FOR
#   home/himalaya.nix is declarative and comes back automatically from a flake
#   rebuild. But the password that unlocks the mail is protected by a GPG key
#   (~/.gnupg) and stored in ~/.password-store — neither lives in the flake.
#   Lose the GPG secret key and the pass store is unrecoverable. Run this
#   before any reinstall / wipe and keep the archive somewhere external
#   (off-box, cloud, USB, another machine).
#
# USAGE
#   bash scripts/backup-mail-secrets.sh [output-dir]
#   (defaults to ~/mail-secrets-backup in the current directory)
#
# RESTORE ON A FRESH INSTALL
#   1. Rebuild the flake (installs himalaya + pass + gpg + writes config).
#   2. gpg --import <archive>/sec.gpg
#   3. pass init <YOUR-KEY-FINGERPRINT>
#   4. Extract the tarball into ~/  (or copy the store files back by hand)
#   5. test:  himalaya envelope list
#
# SECURITY NOTE: your GPG key has NO passphrase (option B setup), so a leaked
# backup archive = a readable pass store. Treat these files like you would the
# app password itself: encrypt the archive / store it only somewhere you trust.
# =============================================================================

set -euo pipefail

KEY_FINGERPRINT="${GPG_KEY_FINGERPRINT:-}"

if [[ -z "${KEY_FINGERPRINT}" ]]; then
  # The key that actually encrypts the pass store is recorded in
  # ~/.password-store/.gpg-id. This is the definitive, unambiguous choice —
  # far more reliable than guessing from the secret keyring (which can contain
  # stale/broken keys that lack an encryption subkey and fail to export).
  GID="${HOME}/.password-store/.gpg-id"
  if [[ -f "${GID}" ]]; then
    KEY_FINGERPRINT=$(tr -d ' \n' < "${GID}")
  fi
  if [[ -z "${KEY_FINGERPRINT}" ]]; then
    echo "error: could not read key from ${GID}" >&2
    echo "set GPG_KEY_FINGERPRINT=<fpr> and retry" >&2
    exit 1
  fi
fi

DEST="${1:-$PWD/mail-secrets-backup}"
mkdir -p "${DEST}"
STAMP="$(date +%Y%m%d)"

echo "==> Backing up GPG secret key ${KEY_FINGERPRINT}"
gpg --batch --export --armor "${KEY_FINGERPRINT}" > "${DEST}/mail-secrets.asc"
gpg --batch --export-secret-keys "${KEY_FINGERPRINT}" \
    > "${DEST}/mail-secrets-private.asc"

echo "==> Verifying the private key exported with secret material"
if ! gpg --list-packets "${DEST}/mail-secrets-private.asc" 2>/dev/null \
    | grep -q ':secret key packet:'; then
  echo "error: private key export did not contain secret material" >&2
  exit 1
else
  echo "    OK: secret key packet present in the private export"
fi

echo "==> Archiving the pass store (~/.password-store)"
if [[ -d "${HOME}/.password-store" ]]; then
  tar -C "${HOME}" -czf "${DEST}/password-store-${STAMP}.tar.gz" .password-store
else
  echo "    warning: no ~/.password-store found, skipping"
fi

echo "==> Backing up gpg-agent trust (so restored key is 'ultimate')"
gpg --export-ownertrust > "${DEST}/ownertrust.txt" 2>/dev/null || true

echo
echo "Backup complete. Contents:"
ls -la "${DEST}"
echo
echo "BACK UP ${DEST} SOMEWHERE OFF THIS MACHINE before reinstalling."
echo "Restore steps are at the top of this script."
