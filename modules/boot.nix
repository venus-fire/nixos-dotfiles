{ config, pkgs, ... }:

{
  # ---- Bootloader: systemd-boot ----
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---- Kernel: latest stable ----
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
