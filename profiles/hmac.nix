{ config, pkgs, ... }:

let
  secretFile = "/etc/signer/hmac.secret";
in
{
  system.activationScripts.hmacSecret = ''
    install -d -m 0750 /etc/signer

    if [ ! -f ${secretFile} ]; then
      echo "Generating HMAC secret..."
      umask 077
      openssl rand -hex 32 > ${secretFile}
      chmod 0400 ${secretFile}
    fi
  '';

  systemd.tmpfiles.rules = [
    "d /etc/signer 0750 root root -"
  ];
}