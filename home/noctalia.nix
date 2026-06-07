{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    # NOTE: settings = { } means the module won't generate any config files.
    #       ~/.config/noctalia/ is a SYMLINK to ~/nixos-dotfiles/config/noctalia/
    #       (created manually: ln -s ~/nixos-dotfiles/config/noctalia ~/.config/noctalia)
    #
    #       This means GUI changes write directly into the dotfiles repo.
    #       To checkpoint: cd ~/nixos-dotfiles && git commit -am "update noctalia"
    #
    #       On a fresh install, run that ln -s command after cloning.
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
