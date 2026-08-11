# =============================================================================
# modules/power.nix — lid close, power management
# =============================================================================
# Two lid-close handling layers:
#   1. udev (AC-unplug trigger) — detects AC disconnect while lid is closed,
#      runs powerChangeScript → suspend.
#   2. niri compositor event (switch-events.lid-close in config/niri/config.kdl)
#      — spawns lid-close on every lid close, which locks (and suspends if
#      on battery). The lid-close binary is installed below.
#
# logind's HandleLidSwitch is set to "ignore" because niri's switch-events
# handles lid-close more precisely (detecting battery vs AC state).
# =============================================================================

{ pkgs, ... }:

let
  # lid-close — CLI tool spawned by niri on lid-close events.
  # Locks the session; also suspends if on battery (discharging).
  # See ../scripts/lid-close.sh for the implementation.
  lid-close = pkgs.writeShellScriptBin "lid-close" (builtins.readFile ../scripts/lid-close.sh);

  # powerChangeScript — called by udev when AC power is unplugged.
  # Suspends if the lid is already closed.
  powerChangeScript = pkgs.writeShellScript "power-change" ''
    LID_STATE=$(cat /proc/acpi/button/lid/LID0/state 2>/dev/null || echo "state:      open")
    if echo "$LID_STATE" | grep -q "closed"; then
      exec ${pkgs.systemd}/bin/systemctl suspend
    fi
  '';
in {
  # Install lid-close on PATH so niri's switch-events can spawn it.
  environment.systemPackages = [ lid-close ];

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${powerChangeScript}"
  '';
}
