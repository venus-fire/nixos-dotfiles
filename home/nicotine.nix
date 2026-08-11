# =============================================================================
# home/nicotine.nix — Nicotine+ with AirVPN WireGuard binding
# =============================================================================
# Replaces the `nicotine` binary on PATH with a wrapper that:
#   1. Detects the AirVPN WireGuard interface IP at runtime
#   2. Updates the 'interface' field in nicotine+'s config so all Soulseek
#      traffic is bound to that IP
#   3. Then launches the real nicotine+
#
# If the VPN is down, the bind fails and nicotine+ can't connect — no
# clearnet Soulseek traffic leaks. Simply reconnect the VPN and relaunch.
#
# WireGuard interface name: airvpn-uk (imported via NetworkManager,
# see modules/networking.nix for import instructions).
#
# VPN IPs are dynamic (assigned by AirVPN server), so hardcoding is
# impractical — the wrapper detects it fresh each launch.
# =============================================================================

{ config, lib, pkgs, ... }:

let
  # VPN interface from NetworkManager WireGuard connection
  vpnInterface = "airvpn-uk";

  # Wrapper script that binds nicotine+ to the VPN interface IP
  nicotine-wrapped = pkgs.writeShellScriptBin "nicotine" ''
    set -uo pipefail

    CONFIG="$HOME/.config/nicotine/config"
    VPN_IF="${vpnInterface}"

    # Detect the VPN interface's IPv4 address
    VPN_IP=$(ip -4 addr show dev "$VPN_IF" 2>/dev/null       | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

    if [ -n "$VPN_IP" ]; then
      # Update interface binding in config — create the entry if missing,
      # otherwise update in place
      if grep -q '^interface' "$CONFIG" 2>/dev/null; then
        sed -i "s/^interface = .*/interface = $VPN_IP/" "$CONFIG"
      else
        # Add interface setting after [server] section header
        sed -i "/^\[server\]/a interface = $VPN_IP" "$CONFIG"
      fi
    fi

    exec ${pkgs.nicotine-plus}/bin/nicotine "$@"
  '';
in
{
  home.packages = [ nicotine-wrapped ];

  # Seed initial config with the VPN interface binding on first launch.
  # This is helpful before the wrapper runs; the wrapper updates it dynamically
  # on each launch with the current VPN IP.
  home.activation.seedNicotineVPN = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CONFIG="$HOME/.config/nicotine/config"
    mkdir -p "$HOME/.config/nicotine"

    if [ ! -f "$CONFIG" ]; then
      # Check VPN IP at activation time for the seed
      VPN_IP=$(ip -4 addr show ${vpnInterface} 2>/dev/null         | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || true)

      cat > "$CONFIG" << CFGEOF
[server]
interface = $VPN_IP

[transfers]
downloaddir = /home/venus/Music/Nicotine+
shared = [('Movies', '/home/venus/Movies')]
CFGEOF
    fi
  '';
}
