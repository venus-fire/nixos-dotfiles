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
    ./qbittorrent.nix        # qBittorrent with I2P-optimised settings
    ./llm.nix                # little-coder + PrismML llama.cpp fork (Vulkan)
  ];
}
