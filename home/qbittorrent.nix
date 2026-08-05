# =============================================================================
# home/qbittorrent.nix — qBittorrent I2P-optimised config
# =============================================================================
# qBittorrent uses its built-in I2P support via the SAM bridge (port 7656).
# When I2P mode is active:
#   - All torrent traffic is tunneled through the I2P network
#   - Only .i2p trackers are used
#   - DHT, PEX, LSD are automatically disabled for I2P torrents
#   - No clearnet IP leaks through torrent traffic
#
# Settings are written as an initial config file. Once qBittorrent runs and
# you change settings through the UI, those take precedence — this file only
# seeds defaults for a first launch.
# =============================================================================

{ config, lib, pkgs, ... }:

let
  qbtConfig = pkgs.writeText "qBittorrent.conf" ''
    [LegalNotice]
    Accepted=true

    [Preferences]
    Advanced\I2P\Enabled=true
    Advanced\I2P\Address=127.0.0.1
    Advanced\I2P\Port=7656
    Advanced\I2P\MixedMode=false
    Advanced\AnonymousMode=true
    Advanced\DisableReannounceWhenDestroyingTorrents=true
    Bittorrent\DHT=false
    Bittorrent\PeX=false
    Bittorrent\LSD=false
    Bittorrent\Encryption=1
    Connection\PortRangeMin=16881
    Connection\UPnP=false
    Connection\ProxyType=0
    Downloads\SavePath=/home/venus/torrents/i2p
    Downloads\TempPath=/home/venus/torrents/.incomplete
    Downloads\PreallocateAll=false
    Downloads\UseIncompleteExtension=false
    Downloads\ScanDirsV2={}
    General\Locale=en
    WebUI\Address=127.0.0.1
    WebUI\Port=8080
    WebUI\Enabled=false
  '';
in
{
  home.packages = with pkgs; [ qbittorrent ];

  # Seed the initial config on first launch only. qBittorrent rewrites this
  # file on every shutdown, so home-manager must not continuously manage it:
  # each activation would try to back up the diverged file into the single-use
  # qBittorrent.conf.backup slot and abort ("would be clobbered"). This hook
  # copies the seed only when the file doesn't exist yet.
  home.activation.seedQBittorrent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/qBittorrent/qBittorrent.conf" ]; then
      mkdir -p "$HOME/.config/qBittorrent"
      cp ${qbtConfig} "$HOME/.config/qBittorrent/qBittorrent.conf"
    fi
  '';
}
