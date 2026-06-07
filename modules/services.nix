{ ... }:

{
  services.syncthing = {
    enable = true;
    user = "venus";
    group = "users";
    dataDir = "/home/venus";
  };

  services.upower.enable = true;

  # udisks2 — D-Bus service for automounting removable drives
  services.udisks2.enable = true;
}
