{ config, pkgs, ... }:

let
  appDir = "/psbt-signer";
in
{

  systemd.services.signer-init = {
    description = "Initialize signer identity";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };


    script = ''
      set -euo pipefail



      STATE=/var/lib/signer/initialized

      if [ -f "$STATE" ]; then
        echo "[*] already initialized"
        exit 0
      fi

      echo "[*] switching to setup mode"
      ${pkgs.nftables}/bin/nft -f /etc/nftables-setup.conf

      mkdir -p /var/lib/signer/data
      mkdir -p /var/lib/signer/wallets

      chown -R root:root /var/lib/signer
      chmod 700 /var/lib/signer/data
      chmod 700 /var/lib/signer/wallets

      echo "[*] building signer container"
      docker compose build


      echo "[*] switching to setup mode"
      #${pkgs.nftables}/bin/nft -f /etc/nftables-locked.conf

      docker compose up

      #Wallet init
      docker exec nixos-psbt-signer-1 python3 exec /psbt-signer/scripts/createSeed.py
      docker exec nixos-psbt-signer-1 python3 exec /psbt-signer/scripts/genWallet.py
      docker exec nixos-psbt-signer-1 python3 exec /psbt-signer/scripts/registerWallet.py

      mkdir -p /var/lib/signer
      touch "$STATE"
    '';

  };
}