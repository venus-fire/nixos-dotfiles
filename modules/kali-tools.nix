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
# =============================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # --- Network scanning & recon ---
    nmap               # port scanner (already provides ncat, nping, ndiff)
    netdiscover        # ARP-based host discovery
    p0f                # passive OS fingerprinting
    dmitry             # deepmagic recon (whois, subdomains, ports)
    dnsenum            # DNS enumeration
    dnsrecon           # DNS recon + zone transfer checks
    subfinder         # subdomain discovery
    amass             # OWASP subdomain enumeration
    theharvester      # email/subdomain OSINT gathering
    sherlock          # username search across social networks
    whatweb           # website fingerprinting
    lbd               # load-balancer detection

    # --- Web application testing ---
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

    # --- Password cracking ---
    hashcat           # GPU/CPU hash cracking (uses your Iris Plus via OpenCL)
    john              # John the Ripper (Jumbo, includes all 2john helpers)
    thc-hydra         # Kali: hydra — network login brute forcer
    medusa            # parallel login brute forcer
    crunch            # wordlist generator
    hashid            # hash type identification
    hash-identifier   # hash type identification (legacy)
    cewl              # wordlist generator from websites
    cowpatty          # WPA2-PSK wordlist attack

    # --- Wi-Fi / wireless ---
    aircrack-ng       # WEP/WPA cracking suite (airmon-ng, airodump-ng, ...)
    airgeddon         # multi-tool wireless attack automation (bash)
    wifite2           # Kali calls it wifite — automated Wi-Fi attack script
    hping             # Kali calls it hping3 — packet crafting / DoS testing
    kismet            # wireless IDS / wardriving
    bluesnarfer       # Bluetooth device exploitation

    # --- MITM / sniffing ---
    bettercap         # MITM framework (ARP/DNS spoofing, network recon)
    ettercap          # classic MITM suite (text mode)
    responder         # LLMNR/NBT-NS/mDNS poisoning
    tcpdump           # packet capture
    snort             # IDS/IPS (needs config + rules to be useful)

    # --- Windows / Active Directory ---
    metasploit        # Kali: metasploit-framework — exploit framework
    mimikatz          # Windows credential dumping (Linux build)
    netexec           # Kali also lists it as crackmapexec (renamed upstream)
    python3Packages.impacket # Kali: impacket-scripts — SMB/MSRPC attack toolkit
    evil-winrm        # WinRM shell for Windows hosts
    enum4linux        # SMB/LDAP enumeration

    # --- Pivoting / C2 ---
    chisel            # fast TCP/UDP tunnel over HTTP
    ligolo-ng         # reverse tunnel (agent + proxy)
    gophish           # phishing campaign toolkit (web UI on localhost)

    # --- Forensics ---
    binwalk           # firmware analysis / file carving
    bulk_extractor    # Kali: bulk-extractor — disk forensics (renamed in nixpkgs)
    foremost          # file carving
    testdisk          # partition recovery (+ photorec)
    apktool           # Android APK reverse engineering
    dex2jar           # APK/DEX → Java bytecode
    yara              # malware pattern matching

    # --- Misc utilities ---
    macchanger        # MAC address spoofing
    exploitdb         # exploit search (searchsploit)
    netcat-openbsd    # Kali: netcat — swiss-army networking tool
    python3Packages.scapy # Kali: scapy — packet manipulation library + CLI
    steghide          # steganography
    powershell        # pwsh — PowerShell for Linux (needed by some toolchains)
    recon-ng          # web recon framework (interactive CLI)
    gemini-cli        # Google Gemini CLI (AI assistant)
  ];
}
