{ config, pkgs, ... }:

{
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.2/24" ];

    listenPort = 51820;

    privateKeyFile = "/etc/wireguard/private.key";

    peers = [
      {
        publicKey = "MIDDLEWARE_PUBLIC_KEY";
        allowedIPs = [ "10.10.0.1/32" ];
      }
    ];
  };
}