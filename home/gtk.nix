{ ... }:

{
  # GTK theme settings — Noctalia generates color CSS overrides in
  # ~/.config/gtk-4.0/, but GTK needs the base theme name to use them.

  gtk = {
    enable = true;

    theme.name = "Adwaita-dark";

    cursorTheme = {
      name = "volantes_cursors";
      size = 24;
    };
  };

  # home-manager's gtk module only sets gtk-theme-name for GTK3, not GTK4.
  # Explicitly write GTK4 settings so Thunar picks it up.
  xdg.configFile."gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=Adwaita-dark
    gtk-application-prefer-dark-theme=1
    gtk-cursor-theme-name=volantes_cursors
    gtk-cursor-theme-size=24
  '';
}
