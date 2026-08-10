{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  # NOTE: The option was renamed upstream from `programs.noctalia-shell`
  #       to `programs.noctalia`. systemd service is now built-in.
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    # v5 config model:
    #   - settings = { } below means the module generates NO config.toml;
    #     noctalia runs on its built-in defaults plus runtime state.
    #   - Runtime settings (Settings UI) are written by noctalia itself to
    #     ~/.local/state/noctalia/settings.toml — a plain writable file that
    #     survives rebuilds, so GUI changes are NOT stored in this repo.
    #   - Plugins are managed with `noctalia msg plugins` (v5 .luau format,
    #     plugin_api 3) and live under ~/.local/state/noctalia/plugins/.
    #
    # To make settings reproducible, copy values from settings.toml into the
    # `settings` attrset below; the module validates them at build time and
    # generates ~/.config/noctalia/config.toml (still overridable at runtime).
    settings = { };
  };
}
