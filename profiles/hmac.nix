{ config, pkgs, ... }:

let
  secretFile = "/var/lib/signer/hmac.secret";
in
{
  system.activationScripts.hmacSecret = ''
    install -d -m 0750 /var/lib/signer

    if [ ! -f ${secretFile} ]; then
      echo "Generating HMAC secret..."
      umask 077
      openssl rand -hex 32 > ${secretFile}
      chmod 0400 ${secretFile}
    fi
  '';
}