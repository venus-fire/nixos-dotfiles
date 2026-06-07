# =============================================================================
# flake.nix — NixOS Flake entry point for host 'venus'
# =============================================================================
#
# A "flake" is a self-contained Nix project that declares its dependencies
# (inputs) and produces things (outputs) — in this case, a bootable NixOS
# system.  Flakes are the modern way to manage NixOS configurations and
# replace the older /etc/nixos/ approach with reproducible, lockable builds.
#
# REBUILD COMMAND (run from this directory or any subdirectory):
#   sudo nixos-rebuild switch --flake .#venus
#
#   - sudo          — most system changes need root
#   - nixos-rebuild — the standard NixOS rebuild tool
#   - switch        — activate the new config NOW (not just build it)
#   --flake .#venus — use the flake in the current dir (.), target host 'venus'
#
# DRY RUN (build only, don't activate — safe to test):
#   nixos-rebuild build --flake .#venus
#   Then check: ./result
#
# UPDATE THE FLAKE.LOCK (refresh all input versions):
#   nix flake update
#
# =============================================================================



# =============================================================================
# THE FLAKE ATTRIBUTE SET
# =============================================================================
# Everything in a flake lives inside a single attribute set { ... }.
# The two top-level keys are 'description' and 'inputs' and 'outputs'.
{
  # A short human-readable label — shows up in `nix flake metadata`.
  description = "NixOS from Scratch — venus configuration";



  # ===========================================================================
  # INPUTS — Where to fetch dependencies from
  # ===========================================================================
  # Each input is a URL to a Git repo or tarball.  The exact version of every
  # input is recorded in flake.lock, so builds are reproducible.  Run
  #   nix flake update
  # to bump everything to the latest commit on the branch specified here.
  inputs = {

    # -------------------------------------------------------------------------
    # nixpkgs — The Nix Packages collection (the entire NixOS & Home Manager
    #           package universe: every program, library, kernel module, etc.)
    # -------------------------------------------------------------------------
    # This is the single most important input.  Pinning to a specific branch
    # (nixos-26.05) means you get stable, tested package versions.  Every other
    # input that also uses nixpkgs should be told to "follow" this one so that
    # everything compiles against the same package set — otherwise you can get
    # version mismatches that cause subtle build failures.
    nixpkgs.url = "nixpkgs/nixos-26.05";

    # -------------------------------------------------------------------------
    # home-manager — Declarative user environment
    # -------------------------------------------------------------------------
    # Home Manager lets you configure user-level things: shell aliases, Git
    # config, GTK themes, background services, and user packages — all in Nix.
    # Without it you'd have to set all that up by hand or with dotfile scripts.
    # It's tied to release-26.05 so its API is compatible with nixos-26.05.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";

      # "follows" tells Nix: "don't fetch a separate copy of nixpkgs for
      # home-manager; use the one I already declared above."  This avoids
      # having two different nixpkgs versions in the same build, which can
      # cause subtle incompatibilities (e.g., a home-manager module expecting
      # a package API that doesn't exist in the system's nixpkgs).
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # noctalia — QtQuick desktop shell (bar, launcher, lock screen, widgets)
    # -------------------------------------------------------------------------
    # Noctalia Shell replaces the traditional desktop environment.  It provides
    # a status bar (with battery, Wi-Fi, clock, audio, etc.), an app launcher,
    # notification centre, lock screen, and desktop widgets — all running on
    # top of a Wayland compositor like niri.
    # Its nixpkgs is also pinned to the same one we use, for the same reason
    # as home-manager above.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";

      # Again: use OUR nixpkgs, not Noctalia's own copy.  This is important
      # because Noctalia pulls in Qt and KDE libraries that must match what
      # the rest of the system uses.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -------------------------------------------------------------------------
    # hermes-agent — CLI AI assistant by Nous Research
    # -------------------------------------------------------------------------
    # Hermes Agent is the AI assistant you're talking to right now.  It runs
    # as a terminal program that can read/write files, execute shell commands,
    # search the web, and more.  It's included as a system package so it's
    # available everywhere.
    # NOTE: We don't use 'follows' here because Hermes doesn't have its own
    # nixpkgs input that needs overriding.  If it did, we'd add it.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
    };

  };  # <-- end of inputs



  # ===========================================================================
  # OUTPUTS — What this flake produces
  # ===========================================================================
  # The 'outputs' function receives all the inputs declared above, plus 'self'
  # (this flake itself).  It must return an attribute set.  Here we produce
  # exactly one thing: a NixOS system configuration named 'venus'.
  #
  # The destructuring pattern 'inputs@{ self, nixpkgs, home-manager, ... }'
  # means:
  #   - 'self' and 'nixpkgs' and 'home-manager' are bound as named variables
  #   - 'inputs' is the ENTIRE input set (so we can pass 'inherit inputs' to
  #     modules that need access to ALL inputs, like the packages module which
  #     uses 'inputs.hermes-agent')
  outputs = inputs@{ self, nixpkgs, home-manager, ... }: {

    # -------------------------------------------------------------------------
    # nixosConfigurations.venus — The NixOS system definition
    # -------------------------------------------------------------------------
    # 'nixosConfigurations' is a special output name that nixos-rebuild looks
    # for.  The attribute name 'venus' matches the hostname and is what you
    # pass after the '#' in '--flake .#venus'.
    nixosConfigurations.venus = nixpkgs.lib.nixosSystem {

      # ---- Target architecture ----
      # x86_64-linux is standard 64-bit Intel/AMD.  On an ARM Mac or Raspberry
      # Pi this would be 'aarch64-linux'.
      system = "x86_64-linux";

      # ---- Extra arguments passed to ALL modules ----
      # Without this, modules (like ./modules/packages.nix) would have no way
      # to access 'inputs.hermes-agent' or 'inputs.noctalia'.  NixOS modules
      # normally only receive { config, pkgs, lib, ... }.  We use specialArgs
      # to additionally inject the full input set under the name 'inputs'.
      specialArgs = { inherit inputs; };

      # ---- Module list ----
      # Modules are Nix files or attribute sets that get merged together.
      # Each module sets some of the options defined in nixpkgs or in other
      # modules.  Order generally doesn't matter — NixOS handles merging via
      # the module system (declarative, not imperative).
      modules = [

        # Our main system-level configuration file.  It imports all the
        # individual concern-based modules from ./modules/ for readability.
        ./configuration.nix

        # ----- Home Manager integration --------------------------------------
        # The home-manager NixOS module adds new NixOS options under
        # 'home-manager.*' and sets up the machinery to build user profiles.
        home-manager.nixosModules.home-manager

        # This inline module configures home-manager's own options for our
        # user.  It's written as an attribute set (anonymous module) rather
        # than a separate file because it's tightly coupled to the flake
        # structure (it references ./home/default.nix by relative path).
        {
          home-manager = {

            # ---- useGlobalPkgs ----
            # When true, home-manager uses the SAME pkgs instance as the NixOS
            # system, instead of building its own.  This means system packages
            # and user packages are linked from the same store path when
            # they're the same package — less disk usage, faster builds.
            useGlobalPkgs = true;

            # ---- useUserPackages ----
            # When true, user packages are installed into the system profile
            # (/run/current-system/sw) instead of a user-specific profile.
            # This makes them accessible to all users and to systemd services.
            # The trade-off is that user packages aren't fully isolated by user.
            useUserPackages = true;

            # ---- backupFileExtension ----
            # When home-manager wants to create a config file (e.g. ~/.bashrc)
            # and one already exists, it renames the existing file by appending
            # ".backup" instead of deleting it.  Safety net for the first run.
            backupFileExtension = "backup";

            # ---- User configuration ----
            # Point home-manager at our user profile for 'venus'.
            # This file (./home/default.nix) is a hub that imports
            # ./home/shell.nix, ./home/noctalia.nix, and ./home/theming.nix.
            users.venus = import ./home/default.nix;

            # ---- Extra arguments for home-manager modules ----
            # Same principle as 'specialArgs' above — passes the flake inputs
            # into home-manager modules so they can reference, e.g.,
            # 'inputs.noctalia' (which home/noctalia.nix needs to import the
            # noctalia home-manager module).
            extraSpecialArgs = { inherit inputs; };

          };
        }
      ];  # <-- end of modules list
    };  # <-- end of nixosConfigurations.venus
  };  # <-- end of outputs
}  # <-- end of the flake
