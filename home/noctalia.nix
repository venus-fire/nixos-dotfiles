{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    # Empty settings = module won't generate a config file.
    # Your old config is placed at ~/.config/noctalia/ as regular files
    # so GUI changes save normally.
    settings = { };
  };

  systemd.user.services.noctalia = {
    Unit = {
      Description = "Noctalia Shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/etc/profiles/per-user/venus/bin/noctalia-shell";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
