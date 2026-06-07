{ pkgs, inputs, ... }:

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
    ripgrep
    fzf
    fd
    yazi
    inputs.hermes-agent.packages.x86_64-linux.default
    keepassxc
    obsidian
    udiskie                          # auto-mounter & CLI helpers for external drives

    brightnessctl                    # backlight control for brightness keys
    gh                               # GitHub CLI
  ];
}
