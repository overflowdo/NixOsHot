{ config, pkgs, ... }:

{
  systemd.services.tpm-unseal = {
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      mkdir -p /run/btc

      tpm2_unseal \
        --object /var/lib/tpm/btc-seed.ctx \
        > /run/btc/seed

      chmod 600 /run/btc/seed
    '';
  };
}