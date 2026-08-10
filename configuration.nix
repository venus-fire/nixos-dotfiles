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
    ./modules/kali-tools.nix          # Kali top-100 CLI security tools
    ./modules/display.nix             # niri compositor & ly display manager
    ./modules/services.nix            # syncthing, upower
    ./modules/freenet.nix             # freenet p2p node
    ./modules/hardware.nix            # bluetooth
    ./modules/nix-settings.nix        # flakes, nix-command
    ./modules/power.nix               # lid close, power management
    ./modules/i2pd.nix                # i2p anonymous overlay network
    ./modules/meshchatx.nix           # reticulum mesh chat web ui
  ];

  # ---- Enable Freenet P2P node (Rust freenet-core) ----
  # Runs the freenet-core daemon as a systemd service on port 31337/udp (P2P)
  # and 7509/tcp (dashboard/API). Dashboard at http://127.0.0.1:7509/.
  services.freenet-core.enable = false;

  # ---- Enable I2P daemon (i2pd) ----
  # Anonymous overlay network. Provides HTTP/SOCKS proxies on localhost:4444
  # and :4447, plus a SAM bridge on :7656 (used by nicotine+). The NTCP2 peer
  # port (15782) is NOT firewalled open by default — client-only.
  services.i2pd.enable = true;

  # ---- Enable MeshChatX (Reticulum mesh chat) ----
  # Headless web UI at http://127.0.0.1:8000 (LXMF chat + LXST telephony).
  # No Electron — the release wheel bundles the frontend. Installed from a
  # pip venv (bootstrapped by the service); update with: meshchatx-update
  services.meshchatx.enable = true;

  # ---- State version ----
  # DO NOT change after first install. Controls defaults for stateful data.
  system.stateVersion = "26.05";
}
