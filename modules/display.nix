{ ... }:

{
  programs.niri.enable = true;
  services.displayManager.ly.enable = true;

  # Propagate cursor theme so xwayland-satellite and other non-niri
  # processes also pick up the custom cursor.
  #
  # NOTE: The same cursor theme is also set at the user level in
  # home/theming.nix (GTK cursor, dconf). Keep both in sync if changing.
  environment.sessionVariables = {
    XCURSOR_THEME = "volantes_cursors";
    XCURSOR_SIZE = "24";
  };

  # ---------------------------------------------------------------------------
  # niri config — symlinked via home-manager (./symlinks.nix)
  # ---------------------------------------------------------------------------
  # ~/.config/niri/config.kdl is a symlink managed by home-manager
  # via xdg.configFile pointing at ~/nixos-dotfiles/config/niri/config.kdl.
  #
  # Edits you make to keybinds, gaps, layouts etc. write directly into git.
  # To checkpoint: cd ~/nixos-dotfiles && git commit -am "update niri config"
  # ---------------------------------------------------------------------------
}
