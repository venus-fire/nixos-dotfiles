{ pkgs, ... }:

{
  # Register Zsh as a known shell so NixOS adds it to /etc/shells
  programs.zsh.enable = true;

  users.users."venus" = {
    isNormalUser = true;
    description = "venus fire";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = [];

    # Set Zsh as the default login shell (replaces Bash)
    shell = pkgs.zsh;
  };
}
