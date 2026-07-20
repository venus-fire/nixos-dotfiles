{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
    };

    # Zsh plugins — enabled declaratively, Home Manager handles the sourcing
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    # Source your existing custom config on top of Home Manager's generated .zshrc
    initContent = "source ~/.zshrc.custom";
  };

  # Place your old .zshrc at ~/.zshrc.custom so Home Manager manages it
  home.file.".zshrc.custom" = {
    source = ../config/zshrc.custom;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "venus-fire";
      user.email = "venus-fire@tutamail.com";
    };
  };

  # Starship — fast, minimal shell prompt
  programs.starship = {
    enable = true;
    # Starship automatically hooks into Zsh via Home Manager's integration
  };
}
