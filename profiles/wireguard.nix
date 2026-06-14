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
      umask 077
      mkdir -p /var/lib/wireguard/
      
      PRIVATE_KEY_FILE="/var/lib/wireguard/private.key"
      PUBLIC_KEY_FILE="/var/lib/wireguard/public.key"

      if [ ! -f "$PRIVATE_KEY_FILE" ]; then
        ${pkgs.wireguard-tools}/bin/wg genkey \
          | tee "$PRIVATE_KEY_FILE" \
          | ${pkgs.wireguard-tools}/bin/wg pubkey \
          > "$PUBLIC_KEY_FILE"
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