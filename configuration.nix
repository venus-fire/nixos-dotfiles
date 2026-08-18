# =============================================================================
# configuration.nix — module hub
# =============================================================================
# This file imports individual modules from ./modules/ for a clean separation
# of concerns. Add or remove module entries here to toggle functionality.
#
# Rebuild with:  sudo nixos-rebuild switch --flake .#venus
# =============================================================================

{ config, pkgs, inputs, ... }:

{
  imports = [
    # Auto-generated hardware scan (device UUIDs, filesystems, swap) — this
    # machine's copy, provided as the 'hardware-config' flake input (see
    # flake.nix) so evaluation stays pure (no --impure needed). A path input
    # resolves to an attrset, so import its outPath (the fetched store copy).
    inputs.hardware-config.outPath

    # --- System modules ---
    ./modules/boot.nix                # bootloader & kernel
    ./modules/networking.nix          # hostname, networkmanager, wifi
    ./modules/locale.nix              # timezone, locale, keyboard layout
    ./modules/users.nix               # user accounts & groups
    ./modules/packages.nix            # system-wide packages
    ./modules/security.nix            # polkit
    ./modules/kali-tools.nix          # Kali top-100 CLI security tools
    ./modules/display.nix             # niri compositor & ly display manager
    ./modules/services.nix            # syncthing, upower, i2pd, meshchatx, freenet, tailscale, udisks2
    ./modules/freenet.nix             # freenet p2p node
    ./modules/hardware.nix            # bluetooth
    ./modules/nix-settings.nix        # flakes, nix-command
    ./modules/power.nix               # lid close, power management
    ./modules/i2pd.nix                # i2p anonymous overlay network
    ./modules/meshchatx.nix           # reticulum mesh chat web ui
    ./modules/caesar.nix              # caesar deep-research web server
  ];

  # Caesar: auto-start the deep-research web server as a system service.
  services.caesar.enable = true;

  # ---- State version ----
  # DO NOT change after first install. Controls defaults for stateful data.
  system.stateVersion = "26.05";
}
