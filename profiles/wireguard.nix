networking.wireguard.interfaces.wg0 = {
  ips = [ "10.10.0.2/24" ];

  privateKeyFile = "/etc/wireguard/private.key";

  peers = [
    {
      publicKey = "";  #Public Key der VM

      allowedIPs = [ "10.10.0.1/32" ];

      endpoint = "192.168.99.78:51820";

      persistentKeepalive = 25;
    }
  ];
};