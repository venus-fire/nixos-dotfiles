# little-coder — a pi-based coding agent optimized for small local models
# https://github.com/itayinbarr/little-coder
#
# buildNpmPackage derivation pinned to the v1.14.0 release tag (rev
# 0b7234031aabe56163e345792ce7a6ea05af321a). The package ships a ready-to-run
# .mjs launcher (bin/little-coder.mjs), so there is no build script —
# npmBuildScript = "" skips the npm run build phase entirely.
#
# Lockfile note: upstream's package-lock.json omits the `integrity` field for
# three nested @earendil-works/pi-* registry deps. The nixpkgs npm-deps fetcher
# (prefetch-npm-deps) refuses non-git deps without integrity, so the vendored
# copy (./package-lock.json) restores the three hashes from the npm registry.
# postPatch swaps it in for both the dep fetch (fetchNpmDeps inherits postPatch)
# and the build, and npmDepsHash is computed against it.
{ lib, buildNpmPackage, fetchFromGitHub, nodejs_22 }:

buildNpmPackage rec {
  pname = "little-coder";
  version = "1.14.0";

  src = fetchFromGitHub {
    owner = "itayinbarr";
    repo = "little-coder";
    rev = "0b7234031aabe56163e345792ce7a6ea05af321a"; # v1.14.0 (2026-07-31)
    hash = "sha256-hv3vSPBkDuNl9L7cX71DGs64//Nzur5dGR9006OqgA8=";
  };

  nodejs = nodejs_22; # engines: node >=22.19.0

  npmDepsHash = "sha256-PhGoTdKTeFOApizbUUwl9aieHwvyg3QrI/W7LyTubhk=";

  # No "build" script in package.json — the launcher ships compiled.
  dontNpmBuild = true;

  # Upstream lockfile entries restored via postPatch carry no cache-control
  # metadata, so npm marks them stale and needs to rewrite the index during
  # offline install. The read-only nix store cache can't take that write →
  # ENOTCACHED. Copy the cache to a writable TMPDIR (hook's documented remedy).
  makeCacheWritable = true;

  postPatch = ''
    cp ${./little-coder/package-lock.json} package-lock.json
  '';

  meta = with lib; {
    description = "A pi-based coding agent optimized for small local language models";
    homepage = "https://github.com/itayinbarr/little-coder";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
