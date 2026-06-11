{ config, pkgs, ... }:

let
  appDir = "/psbt-signer";
in
{
  systemd.services.psbt-signer-init = {
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
    };

    script = ''
      if [ ! -d "/psbt-signer/venv" ]; then
        ${pkgs.python311}/bin/python -m venv /psbt-signer/venv
      fi

      /psbt-signer/venv/bin/pip install --upgrade pip
      /psbt-signer/venv/bin/pip install -r /psbt-signer/requirements.txt
    '';
  };

  systemd.services.psbt-signer = {
    wantedBy = [ "multi-user.target" ];

    requires = [ "psbt-signer-init.service" ];
    after = [ "network.target" "psbt-signer-init.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";

      User = "psbt";
     Group = "psbt";

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];

      WorkingDirectory = "/psbt-signer";

      ExecStart = ''
        /psbt-signer/venv/bin/uvicorn app.signer:app \
          --host 0.0.0.0 \
          --port 8080
      '';
    };
  };

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