{ config, pkgs, ... }:

{
  networking.firewall.enable = false; # deaktivieren
  networking.nftables.enable = true;
  networking.nftables.flushRuleset = false;                 # Docker-Tabellen nicht mitflushen
  networking.nftables.rulesetFile = ./nftables-locked.conf;

  systemd.coredump.enable = false;

  services.journald.extraConfig = ''
    Storage=volatile
  '';


  networking.wireguard.enable = true;

  #DNS
  #services.resolved.enable = false;
  #environment.etc."resolv.conf".text = "nameserver 127.0.0.1";

  #Nur für docker build vor nftables
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  services.resolved.enable = true;

  networking.usePredictableInterfaceNames = false;
}