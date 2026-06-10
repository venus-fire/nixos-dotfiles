{ ... }:

{
  programs.niri.enable = true;
  services.displayManager.ly.enable = true;

  # Cursor theme — set in niri config.kdl's cursor block (handles both the cursor
  # and XCURSOR_THEME/XCURSOR_SIZE env vars for child processes).

  # ---------------------------------------------------------------------------
  # niri config — symlinked into the dotfiles repo
  # ---------------------------------------------------------------------------
  # ~/.config/niri/config.kdl is a symlink to:
  #   ~/nixos-dotfiles/config/niri/config.kdl
  #
  # Edits you make to keybinds, gaps, layouts etc. write directly into git.
  # To checkpoint: cd ~/nixos-dotfiles && git commit -am "update niri config"
  #
  # On a fresh install, after cloning the repo:
  #   ln -s ~/nixos-dotfiles/config/niri/config.kdl ~/.config/niri/config.kdl
  # ---------------------------------------------------------------------------
}
