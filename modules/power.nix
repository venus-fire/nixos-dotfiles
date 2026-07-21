{ ... }:

{
  # Don't let logind handle lid close — niri + Noctalia handle it instead
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
}
