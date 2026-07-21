{ ... }:

{
  programs.niri.enable = true;
  services.displayManager.ly.enable = true;

  # Cursor theme — set in niri config.kdl's cursor block (handles both the cursor
  # and XCURSOR_THEME/XCURSOR_SIZE env vars for child processes).

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
