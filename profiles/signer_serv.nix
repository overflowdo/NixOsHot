{ config, pkgs, ... }:

let
  appDir = "/etc/nixos/";
in
{

  systemd.services.signer-init = {
    description = "Initialize signer identity";
    wantedBy = [ "multi-user.target" "graphical.target" ];

    before = [ "graphical.target" ];

    after = [ 
      "docker.service"
      "wireguard-wg0.service"
      "network-online.target"
    ];
    requires = [ 
      "wireguard-wg0.service"
      "docker.service"
      "network-online.target"
      "nss-lookup.target"
    ];
    wants = [
      "network-online.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = appDir;
    };

    
    script = ''

      STATE=/var/lib/signer/initialized

      sleep 20

      if [ -f "$STATE" ]; then
        echo "[*] already initialized"
        exit 0
      fi
      mkdir -p /var/lib/signer
      mkdir -p /var/lib/signer/tpm
      echo "[*] building signer container"
      ${pkgs.docker}/bin/docker compose build

      echo "[*] switching to locked mode"
      ${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-locked.conf

      ${pkgs.docker}/bin/docker compose up -d

      #Wallet init
      ${pkgs.docker}/bin/docker exec psbt-signer python3 /psbt-signer/scripts/setup/genSeed.py
      ${pkgs.docker}/bin/docker exec psbt-signer python3 /psbt-signer/scripts/setup/genWallet.py

      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/seal.pub /var/lib/signer/tpm/
      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/seal.priv /var/lib/signer/tpm/
      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/sealed.ctx /var/lib/signer/tpm/
      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/pcr.policy /var/lib/signer/tpm/
      
      touch "$STATE"
    '';

  };
}