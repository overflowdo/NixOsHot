{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./profiles/network.nix
    ./profiles/gui.nix
    ./profiles/wireguard.nix
    ./profiles/TPM_unseal_serv.nix
    ./profiles/signer_serv.nix
    ./profiles/base.nix
  ];

  # HARDENING

  services.openssh.enable = false;


  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "kernel.randomize_va_space" = 2;
  };

  security.lockKernelModules = true;
  boot.blacklistedKernelModules = [
    "firewire-core"
    "bluetooth"
  ];

  # disable coredumps
  systemd.coredump.enable = false;

  # volatile logs (no disk persistence)
  services.journald.extraConfig = ''
    Storage=volatile
    Compress=yes
  '';


  # PACKAGES
  environment.systemPackages = with pkgs; [
    python311
    tpm2-tools
    git
    wireguard-tools
    openssl
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.05";
}