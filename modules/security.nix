{ ... }:

{
  security.polkit.enable = true;

  # Grant venus passwordless sudo
  security.sudo.extraRules = [
    {
      users = [ "venus" ];
      commands = [
        { command = "ALL"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
}
