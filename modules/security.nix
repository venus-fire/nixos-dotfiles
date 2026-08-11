{ config, lib, ... }:

let
  categories = config.kaliTools.categories;

  # ---------------------------------------------------------------------------
  # mkSudoAlias — format a Cmnd_Alias block from a category name and path list.
  #
  # Output format (sudoers(5)):
  #   Cmnd_Alias NAME = \
  #       /path/one, \
  #       /path/two, \
  #       /path/three
  # ---------------------------------------------------------------------------
  mkSudoAlias = name: paths:
    let
      firstLine = "Cmnd_Alias ${name} = \\";
      pathLines = lib.imap0 (i: p:
        if i < lib.length paths - 1 then
          "    ${p}, \\"
        else
          "    ${p}"
      ) paths;
    in
    lib.concatStringsSep "\n" ([ firstLine ] ++ pathLines);

  # Each category → one Cmnd_Alias block
  aliasDefs = lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: cat: mkSudoAlias name cat.sudoPaths) categories);

  # Flat list of alias names for the NOPASSWD grant line
  aliasNames = lib.concatStringsSep ", " (builtins.attrNames categories);
in
{
  security.polkit.enable = true;

  # Passwordless sudo for Kali pentest tools — generated from
  # config.kaliTools.categories (defined in modules/kali-tools.nix).
  # Add/edit tool sudo paths in kali-tools.nix, not here.
  security.sudo.extraConfig = ''
    Defaults:venus !requiretty

    ${aliasDefs}

    venus ALL=(ALL:ALL) NOPASSWD: ${aliasNames}
  '';
}

