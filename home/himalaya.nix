# =============================================================================
# home/himalaya.nix — himalaya CLI email client (Gmail) + pass password store
# =============================================================================
# - himalaya reads/writes mail over IMAP (read) and SMTP (send).
# - Gmail requires an App Password (normal password no longer works for
#   IMAP/SMTP). The app password is stored in `pass` (not in this file).
#     pass generate google/app-password
#   Gmail's IMAP/SMTP host/port/encryption are fixed defaults below.
# - Folder aliases are REQUIRED for Gmail: its folders are `[Gmail]/Sent Mail`
#   etc., not `Sent`. Without them, saving to Sent fails AFTER SMTP delivery
#   succeeds, so retrying re-sends the email (duplicates). The plural dotted
#   `folder.aliases.*` form is the one himalaya v1.2.0 actually reads — the
#   older `[accounts.NAME.folder.alias]` sub-section is silently ignored.
#
# REBUILD:
#   sudo nixos-rebuild switch --flake .#venus
#
# USAGE:
#   himalaya envelope list          # read inbox
#   himalaya message read 42        # read a message
#   cat <<EOF | himalaya template send   # send
#   From: ...
#   To: ...
#   Subject: ...
#
#   <body>
#   EOF
# =============================================================================

{ config, pkgs, ... }:

let
  # The Gmail address used for both IMAP and SMTP login, and as the From/Sender.
  account = "gmail";
  email = "fionnafire@gmail.com";
  displayName = "fionnafire";
in
{
  # ---------------------------------------------------------------------------
  # PACKAGES
  # ---------------------------------------------------------------------------
  # himalaya (email CLI) + pass (password store) + gnupg (pass backend).
  home.packages = with pkgs; [
    himalaya        # CLI email client (IMAP + SMTP)
    pass            # password store (holds the Gmail app password)
    gnupg           # GPG — pass store encryption backend
  ];

  # ---------------------------------------------------------------------------
  # GPG — enables gpg + gpg-agent infra that `pass` needs
  # ---------------------------------------------------------------------------
  programs.gpg = {
    enable = true;
    settings = {
      # No changes to defaults are strictly required for pass, but keeping
      # agent settings explicit makes gpg-agent start reliably from a terminal.
    };
  };

  # Graceful gpg-agent daemon (SMTP auth via pass may prompt for the GPG key
  # passphrase on first use).
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;        # keep the passphrase cached for 1h
    maxCacheTtl = 7200;
    pinentryPackage = pkgs.pinentry-curses;  # works headlessly in a terminal
  };

  # ---------------------------------------------------------------------------
  # PASS — the password store itself (data lives in ~/.password-store, which
  # is NOT a /nix/store symlink — it's real user data, seeded imperatively
  # after the first rebuild: see the header comment).
  # ---------------------------------------------------------------------------
  programs.password-store = {
    enable = true;
    package = pkgs.pass;
    settings = {
      PASSWORD_STORE_DIR = "${config.home.homeDirectory}/.password-store";
    };
  };

  # ---------------------------------------------------------------------------
  # HIMALAYA CONFIG
  # ---------------------------------------------------------------------------
  # Written to ~/.config/himalaya/config.toml. Password comes from pass via a
  # command, so no secret lives in the Nix store.
  home.file.".config/himalaya/config.toml" = {
    text = ''
      [accounts.${account}]
      email = "${email}"
      display-name = "${displayName}"
      default = true

      # --- IMAP (reading) ---
      backend.type = "imap"
      backend.host = "imap.gmail.com"
      backend.port = 993
      backend.encryption.type = "tls"
      backend.login = "${email}"
      backend.auth.type = "password"
      backend.auth.cmd = "pass show google/app-password"

      # --- SMTP (sending) ---
      message.send.backend.type = "smtp"
      message.send.backend.host = "smtp.gmail.com"
      message.send.backend.port = 587
      message.send.backend.encryption.type = "start-tls"
      message.send.backend.login = "${email}"
      message.send.backend.auth.type = "password"
      message.send.backend.auth.cmd = "pass show google/app-password"

      # --- Gmail folder mapping (MANDATORY) ---
      # Plural dotted aliases — the only form himalaya v1.2.0 reads.
      folder.aliases.inbox = "INBOX"
      folder.aliases.sent = "[Gmail]/Sent Mail"
      folder.aliases.drafts = "[Gmail]/Drafts"
      folder.aliases.trash = "[Gmail]/Trash"
    '';
  };
}
