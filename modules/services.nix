{ config, lib, ... }:

{
  # ---- Syncthing (P2P file sync) ----
  services.syncthing = {
    enable = true;
    user = "venus";
    group = "users";
    dataDir = "/home/venus";
  };

  # ---- Power management ----
  services.upower.enable = true;

  # ---- udisks2 — D-Bus service for automounting removable drives ----
  services.udisks2.enable = true;

  # ---- Tailscale (WireGuard-based mesh VPN) ----
  services.tailscale.enable = true;

  # ---- Freenet P2P node (Rust freenet-core) ----
  # Runs the freenet-core daemon as a systemd service on port 31337/udp (P2P)
  # and 7509/tcp (dashboard/API). Dashboard at http://127.0.0.1:7509/.
  services.freenet-core.enable = false;

  # ---- I2P daemon (i2pd) ----
  # Anonymous overlay network. Provides HTTP/SOCKS proxies on localhost:4444
  # and :4447, plus a SAM bridge on :7656 (used by nicotine+). The NTCP2 peer
  # port (15782) is NOT firewalled open by default — client-only.
  services.i2pd.enable = true;

  # ---- MeshChatX (Reticulum mesh chat web UI) ----
  # Headless web UI at http://127.0.0.1:8000 (LXMF chat + LXST telephony).
  # No Electron — the release wheel bundles the frontend. Installed from a
  # pip venv (bootstrapped by the service); update with: meshchatx-update
  services.meshchatx.enable = true;
}
