# =============================================================================
# modules/caesar.nix — Caesar autonomous research web server
# =============================================================================
# Runs Caesar (https://github.com/venus-fire/caesar-agent, a fork of
# jasonzliang/caesar-agent) as a hardened systemd *system* service.
#
# The Caesar repo's launcher (web_server/launch.sh) is designed to be run in
# place — it bootstraps a Python venv, npm-installs + builds the Next.js UI,
# then runs the FastAPI backend (:8090) + Next UI (:3000) in the foreground.
# The upstream ships it as a *user* service; here we run the SAME launcher
# under a dedicated system user so it auto-starts at boot, restarts on crash,
# and keeps no secrets in the Nix store.
#
# Why run launch.sh (not a full Nix build): Caesar's Python dep graph
# (chromadb, llama-index, mem0ai, litellm, ...) plus a Next.js production
# build are enormous and high-breakage to build declaratively in Nix. launch.sh
# already handles the venv + npm bootstrap idempotently (sentinel imports, so
# re-starts are fast). It needs a WRITABLE checkout (it writes venv/node_modules/
# .next/logs/data into the tree), so the source is copied from the Nix store
# into a writable state dir ({stateDir}) on first start / on version change.
#
# Networking/keys:
#   * Keys (DEEPSEEK_API_KEY, TAVILY_API_KEY, CAESAR_PASSWORD) come from a
#     root-owned EnvironmentFile, NOT the Nix store. Create it once:
#         sudo install -o root -g root -m 0600 /dev/stdin /etc/caesar/env <<'EOF'
#         DEEPSEEK_API_KEY=sk-...
#         TAVILY_API_KEY=tvly-...
#         EOF
#   * Without the env file the unit still starts (EnvironmentFile=-/... ignores
#     a missing file) and runs in dry-run mode; set keys to run for real.
#   * With a CAESAR_PASSWORD set, launch.sh binds the API to 127.0.0.1 and the
#     UI requires login — recommended for LAN exposure.
#
# The model/provider wiring (DeepSeek chat + local ONNX embeddings + Tavily
# search) lives in the fork's presets (web_server/config_preset/*.yaml and
# caesar/config/config_preset/*.yaml) — see those commits.
# =============================================================================

{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.services.caesar;

  # flake input is `flake = false`, so .outPath is the raw source tree.
  caesarSrc = inputs.caesar-agent.outPath;

  stateDir = cfg.stateDir;

  # Copy the pinned source into the writable state dir when the store path
  # changes (stamped by .caesar-rev). Runs as ROOT in ExecStartPre (via the `+`
  # prefix) because the nix store source is read-only: `cp -aT` would otherwise
  # preserve the store's 0555 mode onto the copy, making the whole tree
  # read-only. After copying we re-own + re-perm the tree to the service user
  # (which also re-fixes any earlier read-only copy). ExecStart itself still
  # drops to the unprivileged `caesar` user.
  copySource = pkgs.writeShellScript "caesar-copy-src" ''
    set -e
    mkdir -p ${stateDir}
    if [ ! -f ${stateDir}/.caesar-rev ] \
       || [ "$(cat ${stateDir}/.caesar-rev 2>/dev/null)" != "${caesarSrc}" ]; then
      echo "caesar: syncing source -> ${stateDir} (${caesarSrc})"
      cp -aT ${caesarSrc} ${stateDir}
      # Un-read-only the copied tree: give the service user rw + dir-traversal.
      chmod -R u+rwX ${stateDir}
      chown -R ${cfg.user}:${cfg.user} ${stateDir}
      echo "${caesarSrc}" > ${stateDir}/.caesar-rev
    fi
  '';

  # Bonus: the caesar CLI on PATH, running from the service's venv. Only usable
  # after the service has built the venv on first start.
  caesarCli = pkgs.writeShellScriptBin "caesar" ''
    if [ ! -x ${stateDir}/web_server/api/.venv/bin/python ]; then
      echo "caesar: service venv not built yet (start caesar-web, then retry)" >&2
      exit 1
    fi
    exec ${stateDir}/web_server/api/.venv/bin/python \
      ${stateDir}/caesar/run_agent.py "$@"
  '';
in
{
  options.services.caesar = {
    enable = lib.mkEnableOption "Caesar autonomous research web server";

    user = lib.mkOption {
      type = lib.types.str;
      default = "caesar";
      description = "Dedicated system user that owns the runtime state dir.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/caesar";
      description = "Writable copy of the repo + venv + build + run data.";
    };

    uiPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port for the Next.js web UI.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open cfg.uiPort in the firewall. Note: NixOS leaves the firewall off
        (networking.firewall.enable = false) on this host, so this is a no-op
        today; it only matters if the firewall is later enabled.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      createHome = true;
    };
    users.groups.${cfg.user} = { };

    # Ensure the state dir exists with the right owner at every boot (and first
    # enable). Files the service creates under it inherit caesar's ownership.
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 ${cfg.user} ${cfg.user} -"
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.uiPort ];

    environment.systemPackages = [ caesarCli ];

    systemd.services.caesar-web = {
      description = "Caesar autonomous research agent web server";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        # No WorkingDirectory: launch.sh does `cd "$(dirname "$0")"` itself, and
        # a unit-level WorkingDirectory would apply to ExecStartPre too (which
        # runs BEFORE the source is copied), causing a CHDIR failure.
        # `+` prefix: copySource runs as ROOT (it needs to fix ownership/modes
        # of the store-derived tree); ExecStart below still runs as `caesar`.
        ExecStartPre = [ "+${copySource}" ];
        EnvironmentFile = "-/etc/caesar/env";
        ExecStart = "${pkgs.bash}/bin/bash ${stateDir}/web_server/launch.sh";
        Restart = "on-failure";
        RestartSec = "10s";

        # launch.sh uses the python venv's uvicorn/next; put toolchain on PATH
        # (systemd ignores a literal `path=`; set PATH via Environment).
        Environment = [
          "HOME=${stateDir}"
          "UI_PORT=${toString cfg.uiPort}"
          "API_PORT=8090"
          "PATH=${pkgs.python3}/bin:${pkgs.nodejs}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.gnutar}/bin:${pkgs.util-linux}/bin:${pkgs.lsof}/bin:${pkgs.ncurses}/bin:${pkgs.uv}/bin:/run/current-system/sw/bin"
          "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
        ];

        # Hardening. ProtectSystem=full read-onlys /usr,/boot,/etc; ${stateDir}
        # stays writable (under /var). ProtectHome stays OFF only because HOME
        # points at ${stateDir} (onnx model cache lives in $HOME/.cache).
        NoNewPrivileges = true;
        ProtectSystem = "full";
        ProtectHome = false;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        MemoryDenyWriteExecute = false; # Python/pip + node/next need W^X-relaxed pte
      };
    };
  };
}
