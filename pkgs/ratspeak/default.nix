# =============================================================================
# pkgs/ratspeak/default.nix — Ratspeak AppImage wrapper for NixOS
# =============================================================================
#
# Fetches the pre-built AppImage from GitHub releases instead of compiling
# from source (which requires ~600 Rust crate deps and takes ages on a laptop).
#
# Uses appimageTools to extract and wrap it so it runs without FUSE.
#
{ pkgs, lib, fetchurl, appimageTools }:

let
  version = "1.0.24";
  src = fetchurl {
    url = "https://github.com/ratspeak/Ratspeak/releases/download/v${version}/Ratspeak-v${version}-linux-x86_64.AppImage";
    hash = "sha256-IOMI2i0r7dHknqN8F7MtNi4Pc9tICaCHoSwp/pf9YIk=";
  };
in
appimageTools.wrapType2 {
  inherit version src;
  pname = "ratspeak";

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    # The AppImage bundles a desktop file; copy it out
    if [ -f "$out/share/applications/ratspeak.desktop" ]; then
      ln -sf "$out/share/applications/ratspeak.desktop" \
        "$out/share/applications/org.ratspeak.desktop.desktop"
    fi
  '';

  meta = {
    description = "Desktop/mobile client for E2EE conversations over Reticulum mesh networking";
    homepage = "https://ratspeak.org";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ratspeak";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
