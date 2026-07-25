# =============================================================================
# modules/freenet.nix — Freenet P2P node service
# =============================================================================
# Sets up the freenet-core daemon as a systemd service, opens the P2P and
# dashboard ports in the firewall, and makes the binary available system-wide.
#
# Uses the overlay from inputs.freenet-core (set in specialArgs via flake.nix)
# so pkgs.freenet resolves to the Rust freenet-core binary, not the old Java
# freenet from nixpkgs.
#
# After rebuilding, start with:
#   sudo systemctl start freenet
# Then open http://127.0.0.1:7509/ for the dashboard.
#
# Ports (both configurable):
#   31337/udp — P2P peer connections
#   7509/tcp  — WebSocket API + web dashboard
# =============================================================================

{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.services.freenet-core;
in
{
  options.services.freenet-core = {
    enable = lib.mkEnableOption "Freenet P2P node (Rust)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "venus";
      description = "System user to run the Freenet daemon as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "System group for the Freenet daemon.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/freenet";
      description = ''
        Directory for Freenet persistent state (peer database, contracts,
        identity keys). Created automatically by systemd StateDirectory.
      '';
    };

    networkPort = lib.mkOption {
      type = lib.types.port;
      default = 31337;
      description = "UDP port for peer-to-peer connections.";
    };

    wsApiPort = lib.mkOption {
      type = lib.types.port;
      default = 7509;
      description = "TCP port for the WebSocket API and web dashboard.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the P2P UDP port in the firewall so other peers can reach
        this node. The dashboard port (TCP) is kept on loopback by
        default — freenet-core's private_network_filter restricts it to
        private IPs only.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--allowed-source-cidrs" "100.64.0.0/10" ];
      description = ''
        Extra CLI arguments passed to `freenet network`. Useful for things
        like allowing Tailscale CGNAT ranges:
          --allowed-source-cidrs 100.64.0.0/10
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Apply the freenet-core overlay so pkgs.freenet resolves to the Rust
    # freenet-core binary instead of the old Java freenet from nixpkgs.
    nixpkgs.overlays = [ inputs.freenet-core.overlays.default ];

    # Install the freenet binary system-wide.
    environment.systemPackages = [ pkgs.freenet ];

    systemd.services.freenet = {
      description = "Freenet P2P Node";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/config ${cfg.dataDir}/logs"
        ];
        ExecStart = lib.concatStringsSep " " ([
          "${pkgs.freenet}/bin/freenet network"
          "--network-port ${toString cfg.networkPort}"
          "--ws-api-port ${toString cfg.wsApiPort}"
          "--data-dir ${cfg.dataDir}"
          "--config-dir ${cfg.dataDir}/config"
          "--log-dir ${cfg.dataDir}/logs"
        ] ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = "10s";

        # systemd-managed state directory (auto-created with correct perms)
        StateDirectory = lib.last (lib.splitString "/" cfg.dataDir);
        WorkingDirectory = cfg.dataDir;

        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = false;  # WASM JIT needs executable memory
      };
    };

    # Firewall: open P2P UDP port so other peers can connect to this node.
    networking.firewall.allowedUDPPorts = lib.optionals cfg.openFirewall [
      cfg.networkPort
    ];

    # The WS API port (7509) is intentionally NOT opened in the firewall by
    # default. freenet-core's private_network_filter restricts it to loopback
    # and RFC1918 addresses. If you need remote access (e.g. via Tailscale),
    # add the CIDR allowlist via extraArgs and open the port explicitly:
    #   networking.firewall.allowedTCPPorts = [ cfg.wsApiPort ];
  };
}
