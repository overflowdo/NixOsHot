{ config, pkgs, lib, ... }:

{

    #User mit Sudo
    users.users.user = {
        isNormalUser = true;
        description = "Admin";
        initialPassword = "changeme";
        extraGroups = [ "wheel" ];
    };

    security.sudo.wheelNeedsPassword = true;


    environment.etc."scripts/wgHMAC_exporth" = {
        source = ./files/wgHMAC_export.sh;
        mode = "0755";
    };


    #Wrappers

    environment.etc."scripts/wrappers/wgHMAC_export.sh" = {
        source = ./files/wrappers/wgHMAC_export.sh;
        mode = "0755";
        
    };


    #Desktop page mit symlinks auf wrappers
    #Legt Ordner beim Boot an (oder beim tmpfiles-setup)
    systemd.tmpfiles.rules = [
        "d /home/user/Desktop 0750 user users - -"
        "d /home/user/Desktop/scripts 0750 user users - -"

        "L+ /home/user/Desktop/scripts/wgHMAC_export.sh - - - - /etc/scripts/wrappers/wgHMAC_export.sh"

        #docker
        # Hauptverzeichnis
        "d /psbt-signer 0770 root 1000 -"
        "d /psbt-signer/run/data 0770 root 1000 -"
        "d /psbt-signer/run/wallets 0770 root 1000 -"
        "d /psbt-signer/scripts 0770 root 1000 -"
        "d /psbt-signer/run/secrets 0770 root 1000 -"

    ];

    systemd.user.services.thunar-exec-shell-scripts = {
    description = "Thunar: execute shell scripts by default";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.xfce.xfconf}/bin/xfconf-query \
          --channel thunar \
          --property /misc-exec-shell-scripts-by-default \
          --create --type bool --set true
      '';
    };
  };
}