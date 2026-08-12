# prime-agent — PrimeIntellect's RLM coding agent CLI (npm release tarball)
#
# Upstream: https://github.com/PrimeIntellect-ai/prime-agent
#
# Why the release tarball instead of building from source:
#   The repo is a 4-workspace TypeScript monorepo (packages/{ai,agent,coding-agent,tui})
#   built with tsgo (the Go-based TS compiler) + esbuild. The published npm tarball
#   ships the already-bundled `dist/` (what `npm install -g` would run), so we package
#   that artifact directly: no TS toolchain, no per-workspace build steps.
#
# Notable quirks handled here:
#   * The tarball has NO package-lock.json. The vendored one at
#     pkgs/prime-agent/package-lock.json was generated from the tarball's package.json
#     (`npm install --package-lock-only`). It is copied in via postPatch so BOTH
#     fetchNpmDeps and the build see the same lockfile (same trick as little-coder).
#   * Its own `dependencies` reference 3 workspace sub-packages from an R2 bucket URL
#     (pub-...r2.dev/...tgz), not the npm registry. npm wrote `integrity` for them when
#     generating the lockfile, so the prefetch fetcher is happy.
#   * Native modules (zeromq, photon-node, optional clipboard) are compiled or picked
#     up as prebuilds during `npm rebuild` inside the config hook — needs cc/make/python,
#     which stdenv + nodejs-slim.python already provide.
#   * The package's own `postinstall` (bootstraps uv + Python into $HOME) never runs:
#     npm ci uses --ignore-scripts and npm rebuild only touches node_modules deps.
#     The kernel runtime is provided declaratively instead — see pkgs/prime-agent-kernel.nix.
#
# To bump the version:
#   1. Change `version`, `hash`, and regenerate the vendored lockfile:
#        cd pkgs/prime-agent
#        # unpack new tgz, copy its package.json here, then:
#        nix shell nixpkgs#nodejs_22 -c npm install --package-lock-only
#   2. Recompute the hashes:
#        nix hash convert --hash-algo sha256 --to sri <sha256-of-new-tgz>
#        NPM_FETCHER_VERSION=1 nix run nixpkgs#prefetch-npm-deps -- pkgs/prime-agent/package-lock.json
{ lib, buildNpmPackage, fetchurl, nodejs_22 }:

buildNpmPackage rec {
  pname = "prime-agent";
  version = "0.7.2";

  src = fetchurl {
    url = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}/prime-agent-${version}.tgz";
    hash = "sha256-vFRx8qYm1ye4ikXrdF//k7EMVUo8T8WRLyXYxkuYf14=";
  };

  # npm pack tarballs unpack to a `package/` subdirectory
  sourceRoot = "package";

  # Hash of the npm dependency tree (from prefetch-npm-deps against the
  # vendored lockfile — see the bump instructions at the top).
  npmDepsHash = "sha256-8VaSwTzXIhsJf2dNjK1oeB67/BzEa9bdCWiJFE9XasI=";

  postPatch = ''
    cp ${./prime-agent/package-lock.json} package-lock.json
  '';

  # dist/ is prebuilt upstream — nothing to compile here
  dontNpmBuild = true;

  # engines: node >= 22.8
  nodejs = nodejs_22;

  meta = {
    description = "Self-improving RLM agent for coding workflows and long-running autonomous tasks";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    license = lib.licenses.mit;
    mainProgram = "prime-agent";
    platforms = lib.platforms.linux;
  };
}
