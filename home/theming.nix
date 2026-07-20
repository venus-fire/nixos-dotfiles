{ pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-theme = "volantes_cursors";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze-dark";
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    cursorTheme = {
      name = "volantes_cursors";
      package = pkgs.volantes-cursors;
      size = 24;
    };
  };

  # Cursor theme — set at system level in modules/display.nix for compositor support.
  # GTK cursor config below ensures consistency in GTK apps.

  home.packages = with pkgs; [ kdePackages.breeze ];

  # KDE color scheme — source the actual Breeze Dark palette from the package.
  xdg.configFile."kdeglobals".source = "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors";

  xdg.configFile."katerc".text = ''
    [UiSettings]
    ColorScheme=Breeze Dark
  '';
}
