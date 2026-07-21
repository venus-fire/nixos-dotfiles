{ ... }:

{
  # Managed symlinks — created by home-manager on activation.
  # No need to manually ln -s on a fresh install.

  xdg.configFile."niri/config.kdl".source = ../config/niri/config.kdl;

  xdg.configFile."noctalia" = {
    source = ../config/noctalia;
    recursive = true;
  };
}
