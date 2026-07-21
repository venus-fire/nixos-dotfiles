{ pkgs, ... }:

let
  # Script called by udev when AC is unplugged: suspends if lid is closed
  powerChangeScript = pkgs.writeShellScript "power-change" ''
    LID_STATE=$(cat /proc/acpi/button/lid/LID0/state 2>/dev/null || echo "state:      open")
    if echo "$LID_STATE" | grep -q "closed"; then
      exec ${pkgs.systemd}/bin/systemctl suspend
    fi
  '';
in {
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${powerChangeScript}"
  '';
}
