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
    ./nicotine.nix           # Nicotine+ with AirVPN WireGuard binding
    ./llm.nix                # little-coder + mainline llama.cpp (Vulkan)
    ./prime-agent.nix        # prime-agent RLM coding agent + kernel env
    ./himalaya.nix           # himalaya CLI email client (Gmail) + pass store
  ];
}
