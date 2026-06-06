{ config, pkgs, ... }:

{
  networking.firewall.enable = true;

  networking.firewall.allowPing = false;

  systemd.coredump.enable = false;

  services.journald.extraConfig = ''
    Storage=volatile
  '';

  networking.firewall = {
    enable = true;

    allowedTCPPorts = [ 8080 ];  # signer API
    allowedUDPPorts = [ 51820 ]; # wireguard
    };
}