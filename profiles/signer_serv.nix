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

      STATE=/var/lib/signer/initialized

      if [ -f "$STATE" ]; then
        echo "[*] already initialized"
        exit 0
      fi

      echo "[*] switching to setup mode"
      ${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-setup.conf

      echo "[*] building signer container"
      docker compose build

      docker compose up -d

      #Wallet init
      docker exec nixos-psbt-signer-1 python3 /psbt-signer/scripts/setup/genSeed.py
      docker exec nixos-psbt-signer-1 python3 /psbt-signer/scripts/setup/genWallet.py
      docker exec nixos-psbt-signer-1 python3 /psbt-signer/scripts/setup/registerWallet.py

      echo "[*] switching to setup mode"
      ${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-locked.conf

      mkdir -p /var/lib/signer
      touch "$STATE"
    '';

  };
}