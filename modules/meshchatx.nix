# =============================================================================
# modules/meshchatx.nix — Reticulum MeshChatX service (web UI, no Electron)
# =============================================================================
# Runs MeshChatX (Reticulum mesh chat: LXMF messaging + LXST telephony) from a
# pip venv as a headless web server at http://127.0.0.1:8000 — the same app as
# the Electron desktop build, without Electron (wheel bundles the frontend).
#
# The venv lives OUTSIDE the nix store at ~/.local/share/meshchatx-venv/
# (pure-Python wheel + pip deps). ExecStartPre bootstraps it on first use;
# updates are done with the `meshchatx-update` script (installed below), which
# re-installs the latest release wheel and restarts the service.
#
# Runtime notes:
# - numpy (LXST dep) needs libstdc++.so.6, which NixOS has no /usr/lib for →
#   LD_LIBRARY_PATH with stdenv.cc.cc.lib. libopus/portaudio are for LXST
#   telephony (same trio the project's own dev shell sets).
# - Reticulum reads AND writes ~/.reticulum (mesh identity + config) and app
#   data lives in the storage dir under home, so ProtectHome must stay OFF
#   (unlike freenet-core — this app writes identity keys on first run).
# - PrivateDevices is intentionally NOT set: LoRa autointerface needs serial
#   (/dev/ttyUSB*) access.
# - RestrictAddressFamilies is intentionally NOT set: Reticulum opens its own
#   sockets (broadcast/raw) for mesh interfaces.
# - Web server binds loopback only — no firewall rules needed. Mesh traffic
#   flows through Reticulum's own sockets, not this port.
# =============================================================================

{ config, pkgs, lib, ... }:

let
  cfg = config.services.meshchatx;

  venvPath = "/home/${cfg.user}/.local/share/meshchatx-venv";

  # Pinned release wheel (bundles the built frontend). Bump when updating.
  wheelUrl = "https://github.com/Quad4-Software/MeshChatX/releases/download/v4.8.1/reticulum_meshchatx-4.8.1-py3-none-any.whl";

  # Bootstrap: create the venv + install the wheel if missing (idempotent).
  bootstrap = pkgs.writeShellScript "meshchatx-bootstrap" ''
    set -e
    mkdir -p ${cfg.storageDir}
    if [ ! -x ${venvPath}/bin/meshchat ]; then
      ${pkgs.python312}/bin/python -m venv ${venvPath}
      ${venvPath}/bin/pip install --quiet ${wheelUrl}
    fi
  '';

  # Wait until every non-loopback interface with a link-local IPv6 has a
  # *bindable* fe80 address before starting. RNS AutoInterface panics (→
  # "Network degraded", app stuck at stage=failed forever) if an interface
  # adopted at discovery can't be bound during final_init — which happens when
  # the service starts while WiFi is still settling right after a
  # NetworkManager restart. Soft timeout: if the link never becomes ready
  # (e.g. LoRa-only / offline), start anyway — AutoInterface with no bindable
  # interfaces only warns, and the TCP hub interface still runs.
  waitNetwork = pkgs.writeShellScript "meshchatx-wait-network" ''
    probe() {
      ${pkgs.python312}/bin/python - <<'PYEOF'
import socket, sys
found = False
with open("/proc/net/if_inet6") as fh:
    for line in fh:
        p = line.split()                      # addr ifindex plen scope flags name
        name = p[5]
        if name == "lo":
            continue
        ip = ":".join(p[0][i:i+4] for i in range(0, 32, 4))
        if not ip.startswith("fe80:"):
            continue
        found = True
        idx = int(p[1], 16)
        s = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
        try:
            s.bind(socket.getaddrinfo(f"{ip}%{idx}", 0,
                      socket.AF_INET6, socket.SOCK_DGRAM)[0][4])
            s.close()
        except OSError:
            sys.exit(1)                        # present but not bindable yet
sys.exit(0 if found else 1)                    # nothing yet: keep waiting
PYEOF
    }

    for i in $(seq 1 15); do             # ~30s window, 2s between probes
      if probe; then
        echo "meshchatx-wait-network: link-local interfaces ready (probe $i)"
        exit 0
      fi
      sleep 2
    done
    echo "meshchatx-wait-network: WARNING no bindable fe80 after 30s, starting anyway" >&2
    exit 0
  '';
in
{
  options.services.meshchatx = {
    enable = lib.mkEnableOption "Reticulum MeshChatX web UI (headless)";

    user = lib.mkOption {
      type = lib.types.str;
      default = "venus";
      description = "User to run MeshChatX as (owns the venv, storage and ~/.reticulum).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the web server listens on. Keep loopback — mesh traffic uses Reticulum's own sockets.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "TCP port for the web UI.";
    };

    storageDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}/.local/share/meshchatx";
      description = "App data directory (chats, contacts, database).";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra CLI arguments passed to meshchat.";
    };
  };

  config = lib.mkIf cfg.enable {
    # `meshchatx-update` — update the wheel to the latest release (see script).
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "meshchatx-update" (builtins.readFile ../scripts/meshchatx-update.sh))
    ];

    systemd.services.meshchatx = {
      description = "Reticulum MeshChatX web UI";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        ExecStartPre = [
          "${bootstrap}"
          "${waitNetwork}"
        ];
        ExecStart = lib.concatStringsSep " " ([
          "${venvPath}/bin/meshchat"
          "--headless"
          "--host ${cfg.host}"
          "--port ${toString cfg.port}"
          "--no-https"
          "--storage-dir ${cfg.storageDir}"
        ] ++ cfg.extraArgs);
        Restart = "on-failure";
        RestartSec = "10s";

        # numpy needs libstdc++.so.6 (NixOS has no /usr/lib) + LXST audio libs
        # PATH: espeak-ng provides the `espeak` binary for voicemail TTS;
        # systemd ignores a literal `path=` directive, so set PATH explicitly
        Environment = [
          "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.libopus}/lib:${pkgs.portaudio}/lib"
          "PATH=${pkgs.espeak-ng}/bin:/run/current-system/sw/bin"
        ];

        # Security hardening — see header comment for what's intentionally off
        NoNewPrivileges = true;
        ProtectSystem = "full";
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
      };
    };
  };
}
