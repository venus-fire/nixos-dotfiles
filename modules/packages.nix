# =============================================================================
# modules/packages.nix — system-wide packages and application-level config
# =============================================================================
# NOTE: this file is for SYSTEM-LEVEL configuration (installed into
# /run/current-system/sw). For user-level packages, see home/*.nix.
#
# Concerns in this file (grouped with section comments):
#   - environment.systemPackages        → system-wide executables
#   - xdg.portal                        → desktop portal backend
#   - programs.steam                    → Steam with -system-composer fix
#   - nixpkgs.config.allowUnfree        → now in modules/nix-settings.nix
#   - lid-close script                  → now in modules/power.nix (power mgmt)
# =============================================================================

{ pkgs, inputs, pkgs-unstable, ... }:

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
  # ---------------------------------------------------------------------------
  # SYSTEM-WIDE PACKAGES
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # --- Browsers & terminals ---
    firefox
    cool-retro-term
    kitty

    # --- Desktop environment tools ---
    fuzzel                            # app launcher (also bound in niri)
    kdePackages.kate                  # KDE text editor
    kdePackages.kio-admin             # admin:// protocol for system file access
    xdg-desktop-portal                # file picker / portal backend
    xdg-utils                         # xdg-open for opening files in default apps
    xwayland-satellite                # X11 apps under Wayland
    wl-clipboard-rs                   # Wayland clipboard
    wtype                             # Wayland keyboard input

    # --- File management ---
    yazi                              # terminal file manager
    fd                                # fast file search
    ripgrep
    fzf                               # fuzzy finder
    ncdu                              # disk usage analyzer
    udiskie                           # auto-mounter & CLI helpers for external drives
    zip

    # --- Messaging & communication ---
    signal-desktop
    nicotine-plus                     # Soulseek client (via I2P)

    # --- Media & entertainment ---
    strawberry                        # music player
    mpv                               # video player
    ffmpeg                            # media converter

    # --- Productivity ---
    keepassxc                         # password manager
    obsidian                          # note-taking
    speedcrunch                       # calculator
    prismlauncher                     # Minecraft launcher

    # --- Development tools ---
    hermes                            # CLI AI agent (Nous Research)
    gh                                # GitHub CLI

    # --- Gaming ---
    gamescope                         # micro-compositor for running games isolated

    # --- Utilities ---
    volantes-cursors                  # cursor theme
    brightnessctl                     # backlight control for brightness keys
    btop                              # system monitor
    wget
    lmstudio                          # local LLM GUI

    # --- Unstable packages ---
    pkgs-unstable.handy               # speech-to-text transcription (nixos-unstable)
    pkgs-unstable.fetch               # file downloader (nixos-unstable)
  ];

  # ---------------------------------------------------------------------------
  # DESKTOP PORTAL — backend for opening files (yazi, xdg-open)
  # ---------------------------------------------------------------------------
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ---------------------------------------------------------------------------
  # STEAM — micro-compositor mode fixes CEF black screen with xwayland-satellite
  # ---------------------------------------------------------------------------
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraArgs = "-system-composer";
    };
  };
}
