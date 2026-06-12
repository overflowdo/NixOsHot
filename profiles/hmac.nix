{ config, pkgs, ... }:

let
  secretFile = "/var/lib/signer/hmac.secret";
in
{
  systemd.services.generate-hmac-secret = {
    description = "Generate HMAC Secret";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      SECRET_FILE="/var/lib/signer/hmac.secret"

      if [ ! -s "$SECRET_FILE" ]; then
        echo "Generating HMAC secret..."

        tmp=$(${pkgs.coreutils}/bin/mktemp)
        umask 077
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$tmp"
        mv "$tmp" "$SECRET_FILE"

        ${pkgs.coreutils}/bin/chown root:1000 "$SECRET_FILE"
        ${pkgs.coreutils}/bin/chmod 0440 "$SECRET_FILE"

        ${pkgs.coreutils}/bin/chown root:1000 /var/lib/signer
        ${pkgs.coreutils}/bin/chmod 0770 /var/lib/signer
      fi
    '';
  };
}