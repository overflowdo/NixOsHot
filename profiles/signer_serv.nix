{ config, pkgs, ... }:

let
  appDir = "/etc/nixos/";
in
{

  systemd.services.signer-init = {
    description = "Initialize signer identity";
    wantedBy = [ "multi-user.target" ];

    after = [ 
      "wireguard-wg0.service"
      "docker.service"
    ];
    requires = [ 
      "wireguard-wg0.service"
      "docker.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = appDir;
    };

    
    script = ''

      STATE=/var/lib/signer/initialized

      if [ -f "$STATE" ]; then
        echo "[*] already initialized"
        exit 0
      fi

      echo "[*] switching to setup mode"
      #${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-setup.conf

      echo "[*] building signer container"
      ${pkgs.docker}/bin/docker compose build

      ${pkgs.docker}/bin/docker compose up -d

      #Wallet init
      ${pkgs.docker}/bin/docker exec nixos-psbt-signer-1 python3 /psbt-signer/scripts/setup/genSeed.py
      ${pkgs.docker}/bin/docker exec nixos-psbt-signer-1 python3 /psbt-signer/scripts/setup/genWallet.py
      ${pkgs.docker}/bin/docker exec nixos-psbt-signer-1 python3 /psbt-signer/scripts/setup/registerWallet.py

      echo "[*] switching to setup mode"
      ${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-locked.conf

      mkdir -p /var/lib/signer
      touch "$STATE"
    '';

  };
}