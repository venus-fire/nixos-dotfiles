# =============================================================================
# modules/i2pd.nix — I2P Daemon (i2pd) configuration
# =============================================================================
# Configures the system i2pd service (provided by nixpkgs' i2pd module).
# The module sets up the daemon user, systemd service, and generates
# i2pd.conf from the option values below.
#
# Provides:
#   - HTTP proxy  (localhost:4444)  — browse .i2p sites
#   - SOCKS proxy (localhost:4447)  — tunnel any TCP traffic
#   - SAM bridge  (localhost:7656)  — programmatic I2P (nicotine+, etc.)
#   - Webconsole  (localhost:7070)  — i2pd status page
#
# The NTCP2 transport port (15782) accepts peer connections. Open it in the
# firewall to participate as a full router (improves the network).
#
# After enabling:
#   sudo systemctl start i2pd
#   journalctl -fu i2pd
#   http://127.0.0.1:7070/
# =============================================================================

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.i2pd;
in
{
  options.services.i2pd.openFirewall = mkOption {
    type = types.bool;
    default = false;
    description = ''
      Open the NTCP2 peer port (15782) in the firewall. Set to true if you
      want to participate as a full router — this helps the I2P network by
      relaying traffic for others. Keep false for a client-only setup.
    '';
  };

  config = mkIf cfg.enable {

    # --- Protocols ---
    # Each protocol entry has { enable, address, port, keys, inbound/outbound }
    services.i2pd.proto = {
      # Webconsole — status page at http://127.0.0.1:7070/
      http.enable = true;

      # HTTP proxy — route browser traffic through I2P at :4444
      httpProxy.enable = true;

      # SOCKS5 proxy — generic TCP tunnel at :4447
      socksProxy.enable = true;

      # SAM bridge — programmatic I2P (nicotine+ soulseek over I2P, etc.)
      sam.enable = true;

      # BOB — off by default (legacy protocol, use SAM instead)
      bob.enable = false;

      # I2CP — off by default (low-level router API)
      i2cp.enable = false;

      # I2PControl — off by default (remote control API)
      i2pControl.enable = false;
    };

    # --- Explorer / auto tunnels ---
    services.i2pd.exploratory = {
      inbound.length = 3;
      inbound.quantity = 6;
      outbound.length = 3;
      outbound.quantity = 6;
    };

    # --- Routing ---
    services.i2pd = {
      # Floodfill — help the netDb. Enable only with high uptime/bandwidth.
      floodfill = false;

      # Virtual interface name
      ifname = mkDefault null;

      # Don't transit traffic in client mode; allow transit when openFirewall
      notransit = !cfg.openFirewall;

      # Bandwidth (KB/s). null = auto
      bandwidth = null;

      # Percentage of bandwidth shared for transit (only matters if notransit=false)
      share = 100;

      # Logging — "error" is quiet; "info" is chatty
      logLevel = "info";

      # Transport
      ntcp2 = {
        enable = true;
        published = cfg.openFirewall;
        port = 15782;
      };
      ssu2.enable = true;
      ssu2.published = cfg.openFirewall;
      ssu2.port = 0;  # 0 = auto
    };

    # --- Package ---
    environment.systemPackages = [ pkgs.i2pd ];

    # --- Firewall ---
    networking.firewall.allowedTCPPorts = optionals (cfg.enable && cfg.openFirewall) [ 15782 ];
    networking.firewall.allowedUDPPorts = optionals (cfg.enable && cfg.openFirewall) [ 15782 ];
  };
}
