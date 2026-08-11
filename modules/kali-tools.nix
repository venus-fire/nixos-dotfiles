# =============================================================================
# kali-tools.nix — Kali Linux TOP-100 CLI tools (security / pentest tooling)
# =============================================================================
# Installable subset of https://www.kali.org/tools/top-100/ as NixOS system
# packages, computed against nixpkgs 26.05 (this system's channel):
#
#   - 67 packages installed here (68 Kali tools; crackmapexec was renamed
#     upstream to netexec, so one package covers both names).
#   - ~1.3 GiB download / ~4 GiB on disk for this set.
#
# EXCLUDED — GUI apps (Electron/Qt/Java desktops, ~1.9 GiB of the full set):
#   wireshark, bloodhound, burpsuite, zap, caido, maltego, autopsy, starkiller
#
# NOT IN nixpkgs at all (22 tools, both 26.05 stable and unstable):
#   beef-xss, wifiphisher, fluxion, spiderfoot, sublist3r, xsstrike, legion,
#   sliver, reaver, rkhunter, tiger, dvwa, sqlsus, nishang, fern-wifi-cracker,
#   sharphound, phishery, maryam, goldeneye, emailharvester,
#   web-cache-vulnerability-scanner, hexstrike-ai
#
# BROKEN / UNAVAILABLE in nixpkgs:
#   mitm6       — python 'future' dep refuses py3.13
#   rainbowcrack — upstream meta.platforms typo ("x86_64-linux64")
#
# nixpkgs renames used (Kali name → nixpkgs attr):
#   zaproxy → zap (GUI, excluded anyway), wifite → wifite2,
#   hping3 → hping, bulk-extractor → bulk_extractor, metasploit-framework → metasploit
#
# NOTE: many of these tools want root — run them via sudo from the terminal.
#
# SHARED CATEGORIES: Each tool category has 'packages' (for environment.systemPackages)
# and 'sudoPaths' (for passwordless sudo in modules/security.nix). Add/remove tools
# in the sudoPaths list at the same time as the packages list. Both are exported as
# config.kaliTools.categories so security.nix reads them programmatically.
# =============================================================================

{ pkgs, lib, config, ... }:

let
  # ===========================================================================
  # Shared tool category definitions
  # ===========================================================================
  # Each attribute has:
  #   packages  — list of pkgs.* for installation in environment.systemPackages
  #   sudoPaths — list of /run/current-system/sw/bin/* paths for NOPASSWD sudo
  #
  # The sudoPaths include not just the primary binary but also sub-commands
  # (e.g. aircrack-ng provides airmon-ng, airodump-ng, etc.; john provides
  # unshadow, unique, undrop; metasploit provides msfconsole, msfvenom, etc.).
  #
  # IMPORTANT: when adding a tool package, also add its sudo paths (at least
  # the primary binary) to the corresponding sudoPaths list below.

  categories = {

    # --- Network scanning & recon ---
    NET_SCANNING = {
      packages = with pkgs; [
        nmap               # port scanner (also provides ncat, nping, ndiff)
        netdiscover        # ARP-based host discovery
        p0f                # passive OS fingerprinting
        dmitry             # deepmagic recon (whois, subdomains, ports)
        dnsenum            # DNS enumeration
        dnsrecon           # DNS recon + zone transfer checks
        subfinder          # subdomain discovery
        amass              # OWASP subdomain enumeration
        theharvester       # email/subdomain OSINT gathering
        sherlock           # username search across social networks
        whatweb            # website fingerprinting
        lbd                # load-balancer detection
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/nmap" "/run/current-system/sw/bin/ncat"
        "/run/current-system/sw/bin/nping" "/run/current-system/sw/bin/netdiscover"
        "/run/current-system/sw/bin/p0f" "/run/current-system/sw/bin/dmitry"
        "/run/current-system/sw/bin/dnsenum" "/run/current-system/sw/bin/dnsrecon"
        "/run/current-system/sw/bin/subfinder" "/run/current-system/sw/bin/amass"
        "/run/current-system/sw/bin/theHarvester" "/run/current-system/sw/bin/sherlock"
        "/run/current-system/sw/bin/whatweb" "/run/current-system/sw/bin/lbd"
      ];
    };

    # --- Web application testing ---
    WEB_APP = {
      packages = with pkgs; [
        gobuster          # directory/DNS/content brute forcing
        dirb              # web content scanner
        dirbuster         # web directory brute forcer (CLI)
        python3Packages.dirsearch # web path scanner (Kali: dirsearch)
        ffuf              # fast web fuzzer
        wfuzz             # web fuzzer (python3Packages)
        nikto             # web server scanner
        wpscan            # WordPress scanner (ruby gems built locally)
        sqlmap            # SQL injection automation
        arjun             # HTTP parameter discovery
        nuclei            # YAML-based vulnerability scanner
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/gobuster" "/run/current-system/sw/bin/dirb"
        "/run/current-system/sw/bin/dirbuster" "/run/current-system/sw/bin/dirsearch"
        "/run/current-system/sw/bin/ffuf" "/run/current-system/sw/bin/wfuzz"
        "/run/current-system/sw/bin/nikto" "/run/current-system/sw/bin/wpscan"
        "/run/current-system/sw/bin/sqlmap" "/run/current-system/sw/bin/arjun"
        "/run/current-system/sw/bin/nuclei"
      ];
    };

    # --- Password cracking ---
    PASSWORD_CRACKING = {
      packages = with pkgs; [
        hashcat           # GPU/CPU hash cracking (uses your Iris Plus via OpenCL)
        john              # John the Ripper (Jumbo, includes all 2john helpers)
        thc-hydra         # Kali: hydra — network login brute forcer (binary: hydra)
        medusa            # parallel login brute forcer
        crunch            # wordlist generator
        hashid            # hash type identification
        hash-identifier   # hash type identification (legacy)
        cewl              # wordlist generator from websites
        cowpatty          # WPA2-PSK wordlist attack
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/hashcat" "/run/current-system/sw/bin/john"
        "/run/current-system/sw/bin/unshadow" "/run/current-system/sw/bin/unique"
        "/run/current-system/sw/bin/undrop" "/run/current-system/sw/bin/hydra"
        "/run/current-system/sw/bin/medusa" "/run/current-system/sw/bin/crunch"
        "/run/current-system/sw/bin/hashid" "/run/current-system/sw/bin/hash-identifier"
        "/run/current-system/sw/bin/cewl" "/run/current-system/sw/bin/cowpatty"
      ];
    };

    # --- Wi-Fi / wireless ---
    WIFI_WIRELESS = {
      packages = with pkgs; [
        aircrack-ng       # WEP/WPA cracking suite (airmon-ng, airodump-ng, ...)
        airgeddon         # multi-tool wireless attack automation (bash)
        wifite2           # Kali calls it wifite — automated Wi-Fi attack script
        hping             # Kali calls it hping3 — packet crafting / DoS testing
        kismet            # wireless IDS / wardriving
        bluesnarfer       # Bluetooth device exploitation
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/aircrack-ng" "/run/current-system/sw/bin/airmon-ng"
        "/run/current-system/sw/bin/airodump-ng" "/run/current-system/sw/bin/aireplay-ng"
        "/run/current-system/sw/bin/airdecap-ng" "/run/current-system/sw/bin/airdecloak-ng"
        "/run/current-system/sw/bin/airolib-ng" "/run/current-system/sw/bin/airserv-ng"
        "/run/current-system/sw/bin/airtun-ng" "/run/current-system/sw/bin/besside-ng"
        "/run/current-system/sw/bin/easside-ng" "/run/current-system/sw/bin/packetforge-ng"
        "/run/current-system/sw/bin/wpaclean" "/run/current-system/sw/bin/kstats"
        "/run/current-system/sw/bin/makeivs-ng" "/run/current-system/sw/bin/airgeddon"
        "/run/current-system/sw/bin/wifite" "/run/current-system/sw/bin/hping3"
        "/run/current-system/sw/bin/kismet" "/run/current-system/sw/bin/bluesnarfer"
      ];
    };

    # --- MITM / sniffing ---
    MITM_SNIFF = {
      packages = with pkgs; [
        bettercap         # MITM framework (ARP/DNS spoofing, network recon)
        ettercap          # classic MITM suite (text mode)
        responder         # LLMNR/NBT-NS/mDNS poisoning
        tcpdump           # packet capture
        snort             # IDS/IPS (needs config + rules to be useful)
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/bettercap" "/run/current-system/sw/bin/ettercap"
        "/run/current-system/sw/bin/responder" "/run/current-system/sw/bin/tcpdump"
        "/run/current-system/sw/bin/snort"
      ];
    };

    # --- Windows / Active Directory ---
    WINDOWS_AD = {
      packages = with pkgs; [
        metasploit        # Kali: metasploit-framework — exploit framework
        mimikatz          # Windows credential dumping (Linux build)
        netexec           # Kali also lists it as crackmapexec (renamed upstream)
        python3Packages.impacket # Kali: impacket-scripts — SMB/MSRPC attack toolkit
        evil-winrm        # WinRM shell for Windows hosts
        enum4linux        # SMB/LDAP enumeration
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/msfconsole" "/run/current-system/sw/bin/msfvenom"
        "/run/current-system/sw/bin/msfdb" "/run/current-system/sw/bin/msfrpc"
        "/run/current-system/sw/bin/msfrpcd" "/run/current-system/sw/bin/netexec"
        "/run/current-system/sw/bin/nxc" "/run/current-system/sw/bin/evil-winrm"
        "/run/current-system/sw/bin/enum4linux"
      ];
    };

    # --- Pivoting / C2 ---
    PIVOT_C2 = {
      packages = with pkgs; [
        chisel            # fast TCP/UDP tunnel over HTTP
        ligolo-ng         # reverse tunnel (agent + proxy)
        gophish           # phishing campaign toolkit (web UI on localhost)
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/chisel" "/run/current-system/sw/bin/ligolo-agent"
        "/run/current-system/sw/bin/ligolo-proxy" "/run/current-system/sw/bin/gophish"
      ];
    };

    # --- Forensics ---
    FORENSICS = {
      packages = with pkgs; [
        binwalk           # firmware analysis / file carving
        bulk_extractor    # Kali: bulk-extractor — disk forensics (renamed in nixpkgs)
        foremost          # file carving
        testdisk          # partition recovery (+ photorec)
        apktool           # Android APK reverse engineering
        dex2jar           # APK/DEX → Java bytecode
        yara              # malware pattern matching
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/binwalk" "/run/current-system/sw/bin/bulk_extractor"
        "/run/current-system/sw/bin/foremost" "/run/current-system/sw/bin/testdisk"
        "/run/current-system/sw/bin/photorec" "/run/current-system/sw/bin/apktool"
        "/run/current-system/sw/bin/d2j-dex2jar" "/run/current-system/sw/bin/d2j-jar2dex"
        "/run/current-system/sw/bin/d2j_invoke" "/run/current-system/sw/bin/yara"
      ];
    };

    # --- Misc utilities ---
    MISC_UTILS = {
      packages = with pkgs; [
        macchanger        # MAC address spoofing
        exploitdb         # exploit search (searchsploit)
        netcat-openbsd    # Kali: netcat — swiss-army networking tool
        python3Packages.scapy # Kali: scapy — packet manipulation library + CLI
        steghide          # steganography
        powershell        # pwsh — PowerShell for Linux (needed by some toolchains)
        recon-ng          # web recon framework (interactive CLI)
        gemini-cli        # Google Gemini CLI (AI assistant)
      ];
      sudoPaths = [
        "/run/current-system/sw/bin/macchanger" "/run/current-system/sw/bin/searchsploit"
        "/run/current-system/sw/bin/nc" "/run/current-system/sw/bin/scapy"
        "/run/current-system/sw/bin/steghide" "/run/current-system/sw/bin/pwsh"
        "/run/current-system/sw/bin/recon-ng" "/run/current-system/sw/bin/gemini"
      ];
    };

  };
in
{
  # ===========================================================================
  # options.kaliTools.categories — exported for use by modules/security.nix
  # ===========================================================================
  # security.nix reads this to generate Cmnd_Alias blocks and the NOPASSWD
  # grant. Keep the sudoPaths here in sync with the packages above.
  options.kaliTools.categories = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          description = "Nixpkgs packages in this category.";
        };
        sudoPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Absolute bin paths for NOPASSWD sudo rules.";
        };
      };
    });
    default = categories;
    defaultText = lib.literalExpression "...";
    description = "Kali tool categories grouping packages and their sudo paths.";
  };

  # ===========================================================================
  # Install all category packages system-wide
  # ===========================================================================
  config.environment.systemPackages = lib.flatten (map (cat: cat.packages) (builtins.attrValues categories));
}
