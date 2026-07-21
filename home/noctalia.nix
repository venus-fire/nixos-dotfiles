{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  # NOTE: The option was renamed upstream from `programs.noctalia-shell`
  #       to `programs.noctalia`. systemd service is now built-in.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    # NOTE: settings = { } means the module won't generate any config files.
    #       ~/.config/noctalia/ is a SYMLINK managed by home-manager
    #       via ./symlinks.nix (xdg.configFile).
    #
    #       This means GUI changes write directly into the dotfiles repo.
    #       To checkpoint: cd ~/nixos-dotfiles && git commit -am "update noctalia"
    settings = { };
  };
}
