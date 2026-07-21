{ pkgs, ... }:

{
  # KDE daemon — needed by Dolphin/KIO to open files
  systemd.user.services.kded = {
    Unit = {
      Description = "KDE Daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.kded}/bin/kded6";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
