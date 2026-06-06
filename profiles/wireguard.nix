{ config, pkgs, ... }:

{
  systemd.services.wg-keygen = {
    description = "Generate WireGuard keypair on first boot";

    wantedBy = [ "multi-user.target" ];

    before = [
      "network.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      mkdir -p /etc/wireguard

      if [ ! -f /etc/wireguard/private.key ]; then
        umask 077

        ${pkgs.wireguard-tools}/bin/wg genkey \
          | tee /etc/wireguard/private.key \
          | ${pkgs.wireguard-tools}/bin/wg pubkey \
          > /etc/wireguard/public.key
      fi
    '';
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.10.0.2/24" ];

    listenPort = 51820;

    privateKeyFile = "/etc/wireguard/private.key";

    peers = [ ];
  };
}