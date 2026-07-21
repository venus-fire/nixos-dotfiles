{ pkgs, inputs, ... }:

let
  # Hermes Agent with Exa web search SDK baked in at build time.
  # The Hermes flake's package supports `override` with extraDependencyGroups
  # to add optional dependency groups (defined in pyproject.toml) that would
  # otherwise be lazy-installed at runtime — which doesn't work on NixOS
  # because the Nix store is read-only.
  #
  # The "exa" group adds exa-py==2.10.2 for the web_search / web_extract tools.
  hermes = inputs.hermes-agent.packages.x86_64-linux.default.override {
    extraDependencyGroups = [ "exa" ];
  };
in
{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    wget
    cool-retro-term
    firefox
    fuzzel
    kdePackages.kate
    kdePackages.kio-admin
    xdg-desktop-portal
    xdg-utils                            # xdg-open for opening files in default apps
    ripgrep
    fzf
    fd
    yazi
    hermes
    keepassxc
    obsidian
    udiskie                              # auto-mounter & CLI helpers for external drives
    brightnessctl                        # backlight control for brightness keys
    gh                                   # GitHub CLI
    gamescope                            # micro-compositor for running Steam/games isolated from XWayland
    signal-desktop
    volantes-cursors                     # cursor theme
    prismlauncher
    ncdu
    xwayland-satellite
    lmstudio
    thunar                            # light file browser (no KDE deps)
  ];

  # Portal backend for file dialogs and opening files
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # -system-composer fixes CEF black screen with xwayland-satellite
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraArgs = "-system-composer";
    };
  };
}
