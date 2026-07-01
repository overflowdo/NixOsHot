{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./profiles/network.nix
    ./profiles/gui.nix
    ./profiles/wireguard.nix
    ./profiles/signer_serv.nix
    ./profiles/base.nix
    ./profiles/hmac.nix
  ];

  # HARDENING

  services.openssh.enable = false;

  #Kernel
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "kernel.randomize_va_space" = 2;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
    "net.ipv4.conf.all.route_localnet" = 0;
  };

  virtualisation.docker.enable = true;

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

  nix.settings.download-buffer-size = 268435456; # 256MB


  # PACKAGES
  environment.systemPackages = with pkgs; [
    tpm2-tools
    tpm2-tss
    pkg-config
    git
    jq
    wireguard-tools
    nftables
    openssl
    docker-compose
  ];

  security.tpm2 = {
    enable = true;
    abrmd.enable = true;
    tctiEnvironment = {
      enable = true;
      interface = "device";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.05";
}