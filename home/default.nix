{ config, pkgs, inputs, ... }:

{
  home.username = "venus";
  home.homeDirectory = "/home/venus";
  home.stateVersion = "26.05";

  imports = [
    ./shell.nix
    ./noctalia.nix
    ./theming.nix
    ./symlinks.nix          # managed symlinks for niri, noctalia config
    ./gtk.nix               # gtk theme settings (Adwaita-dark + noctalia css overlay)
  ];
}
