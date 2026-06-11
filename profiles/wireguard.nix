{ config, pkgs, ... }:

{
  systemd.services.wg-keygen = {
    description = "Generate WireGuard keypair on first boot";

    wantedBy = [ "wireguard-wg0.service" ];
    before = [ "wireguard-wg0.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      mkdir -p /var/lib/wireguard/private.key

      if [ ! -f /var/lib/wireguard/private.key ]; then
        umask 077

        ${pkgs.wireguard-tools}/bin/wg genkey \
          | tee /var/lib/wireguard/private.key \
          | ${pkgs.wireguard-tools}/bin/wg pubkey \
          > /var/lib/wireguard/private.key
      fi
    '';
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.2/24" ];

    privateKeyFile = "/var/lib/wireguard/private.key";

    peers = [
      {
        publicKey = "123";  #Public Key der VM

        allowedIPs = [ "10.10.0.1/32" ];

        endpoint = "192.168.99.78:51820";

        persistentKeepalive = 25;
      }
    ];
  };
}