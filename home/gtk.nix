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

    # home-manager's gtk module doesn't set gtk-theme-name for GTK4
    # by default, so configure it explicitly
    gtk4.extraConfig = {
      gtk-theme-name = "Adwaita-dark";
      gtk-application-prefer-dark-theme = 1;
    };
  };
}
