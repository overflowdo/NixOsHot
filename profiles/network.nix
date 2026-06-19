{ config, pkgs, ... }:

{
  networking.firewall.enable = false; # deaktivieren

  networking.firewall.allowPing = false;

  systemd.coredump.enable = false;

  services.journald.extraConfig = ''
    Storage=volatile
  '';


  networking.wireguard.enable = true;

  #DNS
  #services.resolved.enable = false;
  #environment.etc."resolv.conf".text = "nameserver 127.0.0.1";

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  services.resolved.enable = true;

  systemd.services."-" = {
    serviceConfig = {
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
  };

  networking.nftables.enable = true;
  networking.usePredictableInterfaceNames = false;
}