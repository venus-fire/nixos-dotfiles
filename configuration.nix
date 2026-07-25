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
    ./modules/freenet.nix             # freenet p2p node
    ./modules/hardware.nix            # bluetooth
    ./modules/nix-settings.nix        # flakes, nix-command
    ./modules/power.nix               # lid close, power management
  ];

  # ---- Enable Freenet P2P node (Rust freenet-core) ----
  # Runs the freenet-core daemon as a systemd service on port 31337/udp (P2P)
  # and 7509/tcp (dashboard/API). Dashboard at http://127.0.0.1:7509/.
  services.freenet-core.enable = true;

  # ---- State version ----
  # DO NOT change after first install. Controls defaults for stateful data.
  system.stateVersion = "26.05";
}
