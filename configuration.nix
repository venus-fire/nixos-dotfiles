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
    # Auto-generated hardware scan (device UUIDs, filesystems, swap)
    /etc/nixos/hardware-configuration.nix

    # --- System modules ---
    ./modules/boot.nix                # bootloader & kernel
    ./modules/networking.nix          # hostname, networkmanager, wifi
    ./modules/locale.nix              # timezone, locale, keyboard layout
    ./modules/users.nix               # user accounts & groups
    ./modules/packages.nix            # system-wide packages
    ./modules/security.nix            # polkit
    ./modules/display.nix             # niri compositor & ly display manager
    ./modules/services.nix            # syncthing, upower
    ./modules/hardware.nix            # bluetooth
    ./modules/nix-settings.nix        # flakes, nix-command
  ];

  # ---- State version ----
  # DO NOT change after first install. Controls defaults for stateful data.
  system.stateVersion = "26.05";
}
