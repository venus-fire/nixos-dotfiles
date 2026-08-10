{ ... }:

{
  # Managed symlinks — created by home-manager on activation.
  # No need to manually ln -s on a fresh install.
  #
  # Noctalia's config is deliberately NOT symlinked here: v5 uses a writable
  # state dir (~/.local/state/noctalia) for runtime settings and plugins, and
  # its declarative config is config.toml (see home/noctalia.nix). The old
  # v4 JSON config tree (config/noctalia) was removed from the repo.

  xdg.configFile."niri/config.kdl".source = ../config/niri/config.kdl;
  xdg.configFile."niri/noctalia.kdl".source = ../config/niri/noctalia.kdl;
}
