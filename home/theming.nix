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
    style.name = "adwaita-dark";
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

  xdg.configFile."katerc".text = ''
    [UiSettings]
    ColorScheme=Breeze Dark
  '';
}
