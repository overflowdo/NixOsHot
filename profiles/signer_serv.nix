{ config, pkgs, ... }:

let
  appDir = "/psbt-signer";
in
{
  systemd.services.psbt-signer = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "tpm-unseal.service" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";

      # isolation (keep from earlier)
      DynamicUser = true;
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

      WorkingDirectory = appDir;

      ExecStart = ''
        ${appDir}/venv/bin/uvicorn app.signer:app \
          --host 0.0.0.0 \
          --port 8080
      '';
    };

    preStart = ''
      if [ ! -d "${appDir}/venv" ]; then
        ${pkgs.python311}/bin/python -m venv ${appDir}/venv
      fi

      ${appDir}/venv/bin/pip install --upgrade pip
      ${appDir}/venv/bin/pip install -r ${appDir}/requirements.txt
    '';
  };
}