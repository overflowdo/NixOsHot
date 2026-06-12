{ config, pkgs, ... }:

let
  secretFile = "/var/lib/signer/hmac.secret";
in
{

  systemd.tmpfiles.rules = [
    "d /var/lib/signer 0770 root 1000 - -"
  ];

  systemd.services.generate-hmac-secret = {
    description = "Generate HMAC Secret";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''

      if [ ! -s "$secretFile" ]; then
        echo "Generating HMAC secret..."

        tmp=$(${pkgs.coreutils}/bin/mktemp)
        umask 077
        
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$secretFile"

        ${pkgs.coreutils}/bin/chown root:1000 "$secretFile"
        ${pkgs.coreutils}/bin/chmod 0440 "$secretFile"
      fi
    '';
  };
}