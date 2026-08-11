{ ... }:
{
  security.polkit.enable = true;

  # Passwordless sudo for Kali pentest tools
  security.sudo.extraConfig = ''
# Passwordless sudo for Kali pentest tools — categorized by function.
  # Tools that genuinely need root: nmap (SYN scan), netdiscover, aircrack suite,
  # airgeddon, wifite, hping3, kismet, bettercap, ettercap, responder, tcpdump,
  # snort, macchanger. Others are included for convenience.

  Defaults:venus !requiretty

  Cmnd_Alias NET_SCANNING = \
      /run/current-system/sw/bin/nmap, /run/current-system/sw/bin/ncat, \
      /run/current-system/sw/bin/nping, /run/current-system/sw/bin/netdiscover, \
      /run/current-system/sw/bin/p0f, /run/current-system/sw/bin/dmitry, \
      /run/current-system/sw/bin/dnsenum, /run/current-system/sw/bin/dnsrecon, \
      /run/current-system/sw/bin/subfinder, /run/current-system/sw/bin/amass, \
      /run/current-system/sw/bin/theHarvester, /run/current-system/sw/bin/sherlock, \
      /run/current-system/sw/bin/whatweb, /run/current-system/sw/bin/lbd

  Cmnd_Alias WEB_APP = \
      /run/current-system/sw/bin/gobuster, /run/current-system/sw/bin/dirb, \
      /run/current-system/sw/bin/dirbuster, /run/current-system/sw/bin/dirsearch, \
      /run/current-system/sw/bin/ffuf, /run/current-system/sw/bin/wfuzz, \
      /run/current-system/sw/bin/nikto, /run/current-system/sw/bin/wpscan, \
      /run/current-system/sw/bin/sqlmap, /run/current-system/sw/bin/arjun, \
      /run/current-system/sw/bin/nuclei

  Cmnd_Alias PASSWORD_CRACKING = \
      /run/current-system/sw/bin/hashcat, /run/current-system/sw/bin/john, \
      /run/current-system/sw/bin/unshadow, /run/current-system/sw/bin/unique, \
      /run/current-system/sw/bin/undrop, /run/current-system/sw/bin/medusa, \
      /run/current-system/sw/bin/crunch, /run/current-system/sw/bin/hashid, \
      /run/current-system/sw/bin/hash-identifier, /run/current-system/sw/bin/cewl, \
      /run/current-system/sw/bin/cowpatty

  Cmnd_Alias WIFI_WIRELESS = \
      /run/current-system/sw/bin/aircrack-ng, /run/current-system/sw/bin/airmon-ng, \
      /run/current-system/sw/bin/airodump-ng, /run/current-system/sw/bin/aireplay-ng, \
      /run/current-system/sw/bin/airdecap-ng, /run/current-system/sw/bin/airdecloak-ng, \
      /run/current-system/sw/bin/airolib-ng, /run/current-system/sw/bin/airserv-ng, \
      /run/current-system/sw/bin/airtun-ng, /run/current-system/sw/bin/besside-ng, \
      /run/current-system/sw/bin/easside-ng, /run/current-system/sw/bin/packetforge-ng, \
      /run/current-system/sw/bin/wpaclean, /run/current-system/sw/bin/kstats, \
      /run/current-system/sw/bin/makeivs-ng, /run/current-system/sw/bin/airgeddon, \
      /run/current-system/sw/bin/wifite, /run/current-system/sw/bin/hping3, \
      /run/current-system/sw/bin/kismet, /run/current-system/sw/bin/bluesnarfer

  Cmnd_Alias MITM_SNIFF = \
      /run/current-system/sw/bin/bettercap, /run/current-system/sw/bin/ettercap, \
      /run/current-system/sw/bin/responder, /run/current-system/sw/bin/tcpdump, \
      /run/current-system/sw/bin/snort

  Cmnd_Alias WINDOWS_AD = \
      /run/current-system/sw/bin/msfconsole, /run/current-system/sw/bin/msfvenom, \
      /run/current-system/sw/bin/msfdb, /run/current-system/sw/bin/msfrpc, \
      /run/current-system/sw/bin/msfrpcd, /run/current-system/sw/bin/netexec, \
      /run/current-system/sw/bin/nxc, /run/current-system/sw/bin/evil-winrm, \
      /run/current-system/sw/bin/enum4linux

  Cmnd_Alias PIVOT_C2 = \
      /run/current-system/sw/bin/chisel, /run/current-system/sw/bin/ligolo-agent, \
      /run/current-system/sw/bin/ligolo-proxy, /run/current-system/sw/bin/gophish

  Cmnd_Alias FORENSICS = \
      /run/current-system/sw/bin/binwalk, /run/current-system/sw/bin/bulk_extractor, \
      /run/current-system/sw/bin/foremost, /run/current-system/sw/bin/testdisk, \
      /run/current-system/sw/bin/photorec, /run/current-system/sw/bin/apktool, \
      /run/current-system/sw/bin/d2j-dex2jar, /run/current-system/sw/bin/d2j-jar2dex, \
      /run/current-system/sw/bin/d2j_invoke, /run/current-system/sw/bin/yara

  Cmnd_Alias MISC_UTILS = \
      /run/current-system/sw/bin/macchanger, /run/current-system/sw/bin/searchsploit, \
      /run/current-system/sw/bin/nc, /run/current-system/sw/bin/scapy, \
      /run/current-system/sw/bin/steghide, /run/current-system/sw/bin/pwsh, \
      /run/current-system/sw/bin/recon-ng, /run/current-system/sw/bin/gemini

  venus ALL=(ALL:ALL) NOPASSWD: NET_SCANNING, WEB_APP, PASSWORD_CRACKING, \
      WIFI_WIRELESS, MITM_SNIFF, WINDOWS_AD, PIVOT_C2, FORENSICS, MISC_UTILS

  # Tools not currently installed; add their paths after installing:
  # - hydra: /run/current-system/sw/bin/hydra (add via pkgs.thc-hydra in kali-tools.nix)
  '';
}

