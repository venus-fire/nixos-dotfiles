# =============================================================================
# modules/osint.nix — passive OSINT CLI tools (system-wide)
# =============================================================================
# sherlock + theHarvester already ship via modules/kali-tools.nix (do NOT dup).
# Policy: passive/public collection only, within authorized OSINT scope.
#   - h8mail intentionally EXCLUDED (breach-credential hunting — violates the
#     OSINT "no breach-credential use" rule; k-anonymity hash-prefix only).
#   - login-required / active-scanning tools excluded by default.
# Search: raw Google is blocked on this host (curls to a JS/consent gate) so
#   the dork engine is `ddgr` (DuckDuckGo CLI; honors site:/filetype:/intitle:).
# Attribution discipline: a username/email "hit" is URL-existence only, never
#   proof of identity. See osint skill references/tool_registry.md (L1.0).
# =============================================================================
{ pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    # ---- Tier 0: username/email enumeration + metadata ----
    maigret     # deep username sweep (~2000 sites, tagged/JSON)
    holehe      # email registration-existence check (passive)
    ddgr        # DuckDuckGo CLI — dork engine (site:/filetype:/intitle:)
    exiftool    # EXIF/metadata read (photo provenance/geo)
    mat2        # strip metadata from own assets

    # ---- Tier 1: passive infra / DNS enumeration ----
    subfinder   # passive subdomain discovery
    assetfinder # passive subdomain discovery (alt engine)
    dnsx        # DNS query/probe (subdomain verify + SPF/DKIM/DMARC)
    dnsrecon    # DNS record enumeration

    # ---- Tier 2: heavy / situational — ACTIVATED (user decision 2026-08-19) ----
    amass       # large-scale subdomain/ASN enumeration
    recon-ng    # interactive recon framework (python)
    snscrape    # social content collection (semi-fragile / ToS-sensitive)
    gitleaks    # scan OWN repos for leaked secrets only
  ];
}
