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

{ pkgs, inputs, pkgs-unstable, lib, ... }:

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
    ungoogled-chromium
    librewolf

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
    unzip
    unrar

    # --- Messaging & communication ---
    signal-desktop
    nicotine-plus                     # Soulseek client (VPN-bound via home/nicotine.nix wrapper)

    # --- Media & entertainment ---
    strawberry                        # music player
    mpv                               # video player
    ffmpeg                            # media converter
    yt-dlp                            # media downloader
    python3                           # runtime for scripts/yt-summarize.sh

    # --- Productivity ---
    keepassxc                         # password manager
    obsidian                          # note-taking
    speedcrunch                       # calculator
    prismlauncher                     # Minecraft launcher

    # --- Development tools ---
    hermes                            # CLI AI agent (Nous Research)
    gh                                # GitHub CLI
    pi-coding-agent

    # --- Gaming ---
    gamescope                         # micro-compositor for running games isolated
    faugus-launcher

    # --- Utilities ---
    volantes-cursors                  # cursor theme
    brightnessctl                     # backlight control for brightness keys
    btop                              # system monitor
    wget
    lmstudio                          # local LLM GUI
    trashy

    # --- Authentication ---
    openssh-askpass                   # GTK GUI askpass for sudo -A / ssh prompts

    # --- Unstable packages ---
    pkgs-unstable.handy               # speech-to-text transcription (nixos-unstable)
    pkgs-unstable.fetch               # system info fetcher (like neofetch, nixos-unstable)
  ];

  # ---------------------------------------------------------------------------
  # GUI ASKPASS — GTK password dialog for sudo (-A) and ssh prompts
  # ---------------------------------------------------------------------------
  # openssh-askpass ships libexec/gtk-ssh-askpass, a small GTK3 dialog that
  # fits the GNOME-flavoured auth stack (gcr-ssh-agent, gnome-keyring) and
  # runs natively under Wayland (niri). Noctalia v5 already provides its own
  # polkit agent, so this only covers sudo/ssh passphrase prompts.
  environment.sessionVariables = {
    # sudo -A uses this (aliased in home/shell.nix)
    SUDO_ASKPASS = "${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass";
    # ssh uses this for passphrase prompts; REQUIRE=force makes ssh use the
    # GUI dialog even when a terminal is available.
    SSH_ASKPASS_REQUIRE = "force";
  };

  # programs.ssh pre-defines environment.variables.SSH_ASKPASS="" (normal
  # priority) — mkForce here beats it so ssh actually uses the GUI dialog.
  environment.variables.SSH_ASKPASS = lib.mkForce "${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass";

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
