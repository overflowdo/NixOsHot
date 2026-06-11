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

      /etc/nixos/scripts/gen_wallet.sh

      echo "[*] switching to setup mode"
      ${pkgs.nftables}/bin/nft -f /etc/nftables-locked.conf

      mkdir -p /var/lib/signer
      touch "$STATE"
    '';

  };
}