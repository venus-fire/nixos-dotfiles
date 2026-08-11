# =============================================================================
# modules/nix-settings.nix — Nix daemon configuration
# =============================================================================
# Nix settings that apply to the whole Nix daemon: experimental features,
# unfree package policy, substituters, etc.
# =============================================================================

{ ... }:

{
  # Required for the flake-based workflow (nixos-rebuild --flake, nix flake ...)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow packages with unfree licenses (e.g. Steam, VS Code, unfree firmware)
  nixpkgs.config.allowUnfree = true;
}
