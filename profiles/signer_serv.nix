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
      "generate-hmac-secret.service"
    ];
    requires = [ 
      "wireguard-wg0.service"
      "docker.service"
      "network-online.target"
      "nss-lookup.target"
      "generate-hmac-secret.service"
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

      #GID fuer TPM
      TPM_GID="$(${pkgs.coreutils}/bin/stat -c '%g' /dev/tpmrm0 2>/dev/null || echo 0)"
      if [ "$TPM_GID" = "0" ]; then
        echo "[!] WARNUNG: TPM-Geraetegruppe konnte nicht ermittelt werden, falle auf root(0) zurueck"
        echo "[!] Pruefe 'ls -l /dev/tpmrm0' manuell, falls der Signer-Container keinen TPM-Zugriff bekommt"
      fi

      #.env erstellen
      if [ ! -f /var/lib/signer/.env ]; then
        echo "[*] generating postgres credentials"
        {
          echo "POSTGRES_USER=signer"
          echo "POSTGRES_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 24)"
          echo "POSTGRES_DB=btc"
          echo "TPM_GID=$TPM_GID" 
        } > /var/lib/signer/.env
        chmod 0600 /var/lib/signer/.env
      fi
      ln -sf /var/lib/signer/.env "${appDir}/.env"

      ${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-setup.conf

      echo "[*] building signer container"
      ${pkgs.docker}/bin/docker compose build

      ${pkgs.docker}/bin/docker compose pull postgres proxy

      echo "[*] switching to locked mode"
      ${pkgs.nftables}/bin/nft -f /etc/nixos/profiles/nftables-locked.conf

      ${pkgs.docker}/bin/docker compose up -d

      #Wallet init
      ${pkgs.docker}/bin/docker exec psbt-signer python3 -m app.setup.genSeed

      # Seed-Phrase auf den Desktop (0400, Eigentümer user) und aus dem Volume shreddern
      if [ -f /var/lib/signer/wallets/SEED_PHRASE.txt ]; then
        ${pkgs.coreutils}/bin/install -D -m 0400 -o user -g users \
          /var/lib/signer/wallets/SEED_PHRASE.txt \
          /home/user/Desktop/SEED_PHRASE.txt
        ${pkgs.coreutils}/bin/shred -u /var/lib/signer/wallets/SEED_PHRASE.txt \
          2>/dev/null || rm -f /var/lib/signer/wallets/SEED_PHRASE.txt
      fi

      ${pkgs.docker}/bin/docker exec psbt-signer python3 -m app.setup.genWallet

      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/seal.pub /var/lib/signer/tpm/
      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/seal.priv /var/lib/signer/tpm/
      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/sealed.ctx /var/lib/signer/tpm/
      ${pkgs.docker}/bin/docker cp psbt-signer:/psbt-signer/tpm/pcr.policy /var/lib/signer/tpm/
      
      touch "$STATE"
    '';

  };
}