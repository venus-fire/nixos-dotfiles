# home/default.nix
#
# Hub for the venus home-manager profile. Each concern lives in its own
# module under ./home/. The LLM stack (./llm.nix) is gated by the llm.enable
# option so it can be switched on/off with a single boolean instead of
# commenting blocks out (canonical Nix: module-system merge, not edits).
#
# Toggles:
#   - llm.enable  : local llama.cpp server + little-coder / pi agent wiring.
#                   Flip `config.llm.enable` below.
{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ./shell.nix
    ./noctalia.nix
    ./theming.nix
    ./symlinks.nix          # managed symlinks for niri, noctalia config
    ./qbittorrent.nix        # qBittorrent with I2P-optimised settings
    ./nicotine.nix           # Nicotine+ with AirVPN WireGuard binding
    ./prime-agent.nix        # prime-agent RLM coding agent + kernel env
    ./himalaya.nix           # himalaya CLI email client (Gmail) + pass store
    ./llm.nix                # little-coder + mainline llama.cpp (Vulkan); self-gating
  ];

  # The LLM module reads this option and no-ops when false.
  options.llm.enable =
    lib.mkEnableOption "local llama.cpp LLM stack (llama-server + little-coder + pi)";

  config = {
    home.username = "venus";
    home.homeDirectory = "/home/venus";
    home.stateVersion = "26.05";

    # ---- LLM stack toggle ----
    # Set to `true` to bring llama-server + little-coder/pi back on the next
    # `nixos-rebuild switch`. Everything in ./llm.nix (the systemd user
    # service, provider models, pi config) is gated on this.
    llm.enable = false;
  };
}
