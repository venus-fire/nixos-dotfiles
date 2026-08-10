#!/usr/bin/env bash
# flake-update.sh — nix flake update + bump prime-agent to the latest release
#
# nix flake update cannot be hooked into (builtin command), so this script wraps
# it: first it bumps prime-agent to the latest stable release (or the version
# given as an argument), then it runs `nix flake update` for all flake inputs,
# then (by default) verifies that prime-agent + its kernel env still build.
#
# Usage:
#   scripts/flake-update.sh                # bump prime-agent to latest + flake update
#   scripts/flake-update.sh 0.7.2          # pin prime-agent to 0.7.2 exactly + flake update
#   scripts/flake-update.sh --no-flake-update   # only bump prime-agent (no flake update)
#   scripts/flake-update.sh --no-verify         # skip the verification build
#
# The bump procedure mirrors the comments in pkgs/prime-agent.nix:
#   1. download the release tarball
#   2. regenerate the vendored lockfile from its package.json
#      (postinstall stripped first — npm runs it even with --package-lock-only,
#       and it fails without the bundled dist/; the lockfile itself is unaffected)
#   3. recompute the tarball SRI (nix hash file) and npmDepsHash (prefetch-npm-deps)
#   4. patch version / hash / npmDepsHash in pkgs/prime-agent.nix
#
# The script does NOT commit — review `git diff` and commit yourself (or ask the
# agent). After committing, switch with:
#   sudo nixos-rebuild switch --flake .#venus --impure
set -uo pipefail

# Repo root: BASH_SOURCE works when run from the checkout (the zsh alias in
# home/shell.nix points there). FLAKE_UPDATE_REPO overrides it (needed if the
# script is ever installed into the nix store, where BASH_SOURCE won't point
# at the repo).
REPO="${FLAKE_UPDATE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [ ! -f "$REPO/pkgs/prime-agent.nix" ]; then
  echo "error: dotfiles repo not found (no pkgs/prime-agent.nix under $REPO)" >&2
  echo "hint: run from the checkout, or set FLAKE_UPDATE_REPO to the repo path" >&2
  exit 1
fi
cd "$REPO"

PKG_NIX="pkgs/prime-agent.nix"
LOCKFILE="pkgs/prime-agent/package-lock.json"
REPO_URL="https://github.com/PrimeIntellect-ai/prime-agent"
API_URL="https://api.github.com/repos/PrimeIntellect-ai/prime-agent/releases/latest"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---------------------------------------------------------------------------
# argument parsing
# ---------------------------------------------------------------------------
DO_FLAKE_UPDATE=1
DO_VERIFY=1
TARGET_VERSION=""
for arg in "$@"; do
  case "$arg" in
    --no-flake-update) DO_FLAKE_UPDATE=0 ;;
    --no-verify) DO_VERIFY=0 ;;
    -h | --help)
      grep -E '^# ' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) TARGET_VERSION="$arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# current pinned version
# ---------------------------------------------------------------------------
CURRENT="$(grep -oP '^  version = "\K[^"]+' "$PKG_NIX" | head -1)"
if [ -z "$CURRENT" ]; then
  echo "error: could not read version from $PKG_NIX" >&2
  exit 1
fi
echo "prime-agent currently pinned: $CURRENT"

# ---------------------------------------------------------------------------
# resolve target version
# ---------------------------------------------------------------------------
if [ -z "$TARGET_VERSION" ]; then
  echo "checking latest stable release on GitHub..."
  TARGET_VERSION="$(curl -fsSL "$API_URL" | grep -oP '"tag_name":\s*"\K[^"]+' | head -1 | sed 's/^v//')"
  if [ -z "$TARGET_VERSION" ]; then
    echo "error: failed to query $API_URL (rate limit?)" >&2
    exit 1
  fi
  echo "latest stable release: $TARGET_VERSION"

  if [ "$TARGET_VERSION" = "$CURRENT" ]; then
    echo "prime-agent already at $CURRENT — nothing to bump"
    TARGET_VERSION=""
  elif [ "$(printf '%s\n' "$CURRENT" "$TARGET_VERSION" | sort -V | tail -1)" = "$CURRENT" ]; then
    echo "error: latest release $TARGET_VERSION is older than pinned $CURRENT — pass a version explicitly to pin down" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# bump prime-agent (download, lockfile, hashes, patch)
# ---------------------------------------------------------------------------
if [ -n "$TARGET_VERSION" ]; then
  TGZ="prime-agent-${TARGET_VERSION}.tgz"
  URL="${REPO_URL}/releases/download/v${TARGET_VERSION}/${TGZ}"
  echo "bumping prime-agent to $TARGET_VERSION"
  echo "  downloading $URL"
  curl -fsSL -o "$WORKDIR/$TGZ" "$URL" || {
    echo "error: failed to download $URL" >&2
    exit 1
  }

  # extract package.json for lockfile generation
  tar xzf "$WORKDIR/$TGZ" -C "$WORKDIR" package/package.json || {
    echo "error: unexpected tarball layout (no package/package.json)" >&2
    exit 1
  }

  # regenerate the vendored lockfile (postinstall stripped: it fails without
  # dist/ and is irrelevant to the lockfile)
  mkdir -p "$WORKDIR/lockgen"
  cp "$WORKDIR/package/package.json" "$WORKDIR/lockgen/package.json"
  sed -i 's/"postinstall"[[:space:]]*:[[:space:]]*"node postinstall\.cjs"/"postinstall": ""/' "$WORKDIR/lockgen/package.json"
  (
    cd "$WORKDIR/lockgen" || exit 1
    if ! nix shell nixpkgs#nodejs_22 -c npm install --package-lock-only --no-fund --no-audit >/dev/null 2>&1; then
      # npm exits non-zero here if the (stripped) postinstall still fails; the
      # lockfile is what matters — fall through and validate it below
      true
    fi
  )
  if [ ! -s "$WORKDIR/lockgen/package-lock.json" ]; then
    echo "error: lockfile generation failed" >&2
    exit 1
  fi

  # guard against the little-coder failure mode: URL deps (r2.dev bucket) must
  # carry integrity or the prefetch fetcher panics
  if grep -q 'r2\.dev' "$WORKDIR/lockgen/package-lock.json" && ! grep -q '"integrity"' "$WORKDIR/lockgen/package-lock.json"; then
    echo "error: lockfile has r2.dev URL deps without integrity — cannot prefetch" >&2
    exit 1
  fi

  cp "$WORKDIR/lockgen/package-lock.json" "$LOCKFILE"
  echo "  vendored lockfile updated"

  # recompute hashes
  NEW_SRI="$(nix hash file --type sha256 --sri "$WORKDIR/$TGZ")" || {
    echo "error: nix hash file failed" >&2
    exit 1
  }
  NEW_NPMDEPS="$(NPM_FETCHER_VERSION=1 nix run nixpkgs#prefetch-npm-deps -- "$WORKDIR/lockgen/package-lock.json" 2>/dev/null | tail -1)" || {
    echo "error: prefetch-npm-deps failed" >&2
    exit 1
  }
  case "$NEW_NPMDEPS" in
    sha256-*) ;;
    *) echo "error: prefetch-npm-deps returned unexpected output: $NEW_NPMDEPS" >&2; exit 1 ;;
  esac

  # patch pkgs/prime-agent.nix (| delimiter: SRI base64 never contains '|')
  sed -i "s|^  version = \".*\";|  version = \"$TARGET_VERSION\";|" "$PKG_NIX"
  sed -i "s|^    hash = \"sha256-[^\"]*\";|    hash = \"$NEW_SRI\";|" "$PKG_NIX"
  sed -i "s|^  npmDepsHash = \"sha256-[^\"]*\";|  npmDepsHash = \"$NEW_NPMDEPS\";|" "$PKG_NIX"

  echo "  pkgs/prime-agent.nix patched:"
  grep -E '^  (version|npmDepsHash)|^    hash' "$PKG_NIX"
fi

# ---------------------------------------------------------------------------
# nix flake update (all inputs)
# ---------------------------------------------------------------------------
if [ "$DO_FLAKE_UPDATE" = 1 ]; then
  echo "running nix flake update..."
  nix flake update || {
    echo "error: nix flake update failed" >&2
    exit 1
  }
else
  echo "skipping nix flake update (--no-flake-update)"
fi

# ---------------------------------------------------------------------------
# verification: prime-agent CLI + kernel env (kernel's src is the CLI package,
# so one build covers both). --no-verify to skip.
# ---------------------------------------------------------------------------
if [ "$DO_VERIFY" = 1 ]; then
  echo "verifying prime-agent + kernel env build..."
  OUT="$(nix build --impure --no-link --print-out-paths '.#nixosConfigurations.venus.pkgs.prime-agent-kernel' 2>&1 | tail -1)" || {
    echo "error: verification build failed — see output above. Check whether the new release changed dist/ layout or skill pyprojects (pkgs/prime-agent-kernel.nix)." >&2
    exit 1
  }
  echo "  verified: $OUT"
fi

# ---------------------------------------------------------------------------
echo
echo "done."
echo "next steps:"
if [ -n "$TARGET_VERSION" ]; then
  echo "  git diff pkgs/prime-agent.nix pkgs/prime-agent/package-lock.json   # review"
  echo "  git add -A && git commit -m \"bump prime-agent to $TARGET_VERSION\"  # commit"
else
  echo "  prime-agent not bumped (already current) — nothing extra to commit"
fi
echo "  sudo nixos-rebuild switch --flake .#venus --impure                  # activate"
