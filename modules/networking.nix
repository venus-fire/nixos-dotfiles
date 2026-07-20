{ ... }:

{
  networking.hostName = "venus";
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # WireGuard VPN — imported via NetworkManager (not managed declaratively)
  # ---------------------------------------------------------------------------
  # Provider .conf files contain private keys, so they're NOT stored in this
  # repo. To add a new VPN:
  #
  #   1. Rename the provider .conf to a valid interface name (e.g. wg-airvpn.conf)
  #   2. Import into NetworkManager:
  #        nmcli connection import type wireguard file ~/Downloads/wg-airvpn.conf
  #
  # The VPN then appears in the Noctalia network widget for toggling on/off.
  # Imported configs persist in NetworkManager's own storage across rebuilds.
  # ---------------------------------------------------------------------------
}
