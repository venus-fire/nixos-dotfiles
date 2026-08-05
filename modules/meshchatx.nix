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
