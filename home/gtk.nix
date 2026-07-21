{ ... }:

{
  # GTK theme settings — Noctalia generates color CSS overrides in
  # ~/.config/gtk-4.0/, but GTK4 needs the base theme name to use them.

  gtk = {
    enable = true;

    # Use Adwaita-dark so Noctalia's gtk.css color overrides work
    theme.name = "Adwaita-dark";

    cursorTheme = {
      name = "volantes_cursors";
      size = 24;
    };
  };
}
