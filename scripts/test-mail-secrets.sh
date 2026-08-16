#!/usr/bin/env bash
# =============================================================================
# scripts/test-mail-secrets.sh — SAFE round-trip test for the backup/restore
# mail-secrets scripts, using triple isolation so the REAL ~/.password-store
# and REAL gpg keyring can never be written to (or read) by the test.
#
# WHY PASSWORD_STORE_DIR IS REQUIRED
#   pass normally resolves the store from $HOME/.password-store. A test that
#   overrides HOME but forgets that an env-alias or config points elsewhere can
#   silently clobber the real store. So this harness overrides HOME, GNUPGHOME
#   AND sets PASSWORD_STORE_DIR to a throwaway dir. That makes it impossible
#   for a generated test secret to land in a real store.
#
# USAGE
#   bash scripts/test-mail-secrets.sh
#
# EXIT 0 => all assertions passed, real store untouched.
# =============================================================================

set -uo pipefail
FAILED=0

# --- real-store fingerprint captured BEFORE anything runs --------------------
REAL_DIR="${PASSWORD_STORE_DIR:-${HOME}/.password-store}"
if [[ -d "${REAL_DIR}" ]]; then
  REAL_MANIFEST=$(cd "${REAL_DIR}" && find . -type f | sort \
    | while read -r f; do printf '%s %s\n' "$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)" "$f"; done)
else
  REAL_MANIFEST="<no store at ${REAL_DIR}>"
fi

# --- isolated sandbox --------------------------------------------------------
# Everything lives under an isolated HOME; PASSWORD_STORE_DIR is aligned to
# that home's .password-store so pass AND the backup/restore scripts agree on
# the same store, and neither can ever resolve to the real one.
T=$(mktemp -d /tmp/himalaya-test.XXXXXX)
SH="$T/src-home"; DH="$T/dst-home"; SG="$T/src-gpg"; DG="$T/dst-gpg"
SRC_PWD="$SH/.password-store"; DST_PWD="$DH/.password-store"
mkdir -p "$SH" "$DH" "$SG" "$DG"
chmod 700 "$SG" "$DG"

run_pass() {  # GNUPGHOME=$1 STORE=$2 [extra...] pass ...
  local kg="$1" sp="$2"; shift 2
  GNUPGHOME="$kg" HOME="$(dirname "$sp")" PASSWORD_STORE_DIR="$sp" pass "$@"
}

echo "==> A. build throwaway key + store (src)"
GNUPGHOME="$SG" HOME="$SH" PASSWORD_STORE_DIR="$SRC_PWD" gpg --batch --generate-key >/dev/null 2>&1 <<'EOF'
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: test
Name-Email: test@example.com
Expire-Date: 0
%commit
EOF
FPR=$(GNUPGHOME="$SG" HOME="$SH" PASSWORD_STORE_DIR="$SRC_PWD" gpg --list-secret-keys --with-colons \
  | awk -F: '$1=="fpr"{print $10; exit}')
mkdir -p "$SRC_PWD"; echo "$FPR" > "$SRC_PWD/.gpg-id"
printf 'LABVALUE\n' > "$T/plain.txt"
mkdir -p "$SRC_PWD/google"
GNUPGHOME="$SG" gpg --batch --yes --recipient "$FPR" --trust-model always \
  --encrypt --output "$SRC_PWD/google/app-password.gpg" "$T/plain.txt" 2>&1 | tail -1
if run_pass "$SG" "$SRC_PWD" show google/app-password 2>/dev/null | grep -q LABVALUE; then
  echo "    PASS: isolated src store seeded + decrypts"
else echo "    FAIL: src seed"; FAILED=1; fi

echo "==> B. backup (src -> archive)"
BK="$T/backup"
GNUPGHOME="$SG" HOME="$SH" PASSWORD_STORE_DIR="$SRC_PWD" bash \
  /home/venus/Documents/nixos-dotfiles/scripts/backup-mail-secrets.sh "$BK" >/dev/null 2>&1
if [[ -s "$BK/mail-secrets-private.asc" && -n $(ls "$BK"/password-store-*.tar.gz 2>/dev/null) ]]; then
  echo "    PASS: archive produced"
else echo "    FAIL: backup incomplete"; FAILED=1; fi

echo "==> C. restore into clean dst (fresh keyring, store wiped)"
rm -rf "$DG"; mkdir -p "$DG"; chmod 700 "$DG"
GNUPGHOME="$DG" HOME="$DH" PASSWORD_STORE_DIR="$DST_PWD" bash \
  /home/venus/Documents/nixos-dotfiles/scripts/restore-mail-secrets.sh "$BK" > "$T/restore.log" 2>&1
rc=$?
grep -E 'OK:|error|complete' "$T/restore.log" | sed 's/^/    /'
if [[ $rc -eq 0 ]]; then echo "    PASS: restore exit 0"; else echo "    FAIL: restore exit $rc"; FAILED=1; fi

echo "==> D. restored store decrypts"
if run_pass "$DG" "$DST_PWD" show google/app-password 2>/dev/null | grep -q LABVALUE; then
  echo "    PASS"
else echo "    FAIL"; FAILED=1; fi

echo "==> E. .gpg-id matches restored key"
RID=$(cat "$DST_PWD/.gpg-id" 2>/dev/null)
if [[ -n "$RID" && "$RID" == "$FPR" ]]; then echo "    PASS"; else echo "    FAIL"; FAILED=1; fi

echo "==> F. safety guard in restore still refuses on existing store"
echo x > "$DST_PWD/google/inject.gpg"
GNUPGHOME="$DG" HOME="$DH" PASSWORD_STORE_DIR="$DST_PWD" bash \
  /home/venus/Documents/nixos-dotfiles/scripts/restore-mail-secrets.sh "$BK" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then echo "    PASS: refused"; else echo "    FAIL"; FAILED=1; fi
rm -f "$DST_PWD/google/inject.gpg"

# --- NON-NEGOTIABLE: real store must be byte-identical to before --------------
echo "==> G. REAL store untouched (manifest compare)"
if [[ "${REAL_MANIFEST}" == "<no store"* ]]; then
  echo "    PASS: no real store present"
elif [[ -d "${REAL_DIR}" ]]; then
  NOW=$(cd "${REAL_DIR}" && find . -type f | sort \
    | while read -r f; do printf '%s %s\n' "$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)" "$f"; done)
  if [[ "$NOW" == "$REAL_MANIFEST" ]]; then echo "    PASS: real store unchanged"; else echo "    FAIL: REAL STORE CHANGED!"; FAILED=1; fi
fi

rm -rf "$T"
if [[ $FAILED -eq 0 ]]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
