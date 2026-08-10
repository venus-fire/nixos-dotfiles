{ config, ... }:

{
  # Managed symlinks — created by home-manager on activation.
  # No need to manually ln -s on a fresh install.
  #
  # These use mkOutOfStoreSymlink so the LIVE files ARE the repo files:
  # edit ~/.config/niri/config.kdl (or the repo copy directly), reload, and
  # the config is backed up by git — no read-only store round-trip.
  #
  # Tradeoff: symlink targets are absolute, so the repo must live at
  # ~/Documents/nixos-dotfiles on every machine.
  #
  # Noctalia: only config.toml is symlinked here (the hand-edited declarative
  # layer). The Settings UI writes ~/.local/state/noctalia/settings.toml
  # atomically (temp+rename), which would silently replace a symlink — never
  # symlink that file. Snapshot it into the repo instead with
  # `noctalia-backup` (see scripts/noctalia-backup.sh).

  xdg.configFile."niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink ../config/niri/config.kdl;
  xdg.configFile."niri/noctalia.kdl".source = config.lib.file.mkOutOfStoreSymlink ../config/niri/noctalia.kdl;
  xdg.configFile."noctalia/config.toml".source = config.lib.file.mkOutOfStoreSymlink ../config/noctalia/config.toml;
}
