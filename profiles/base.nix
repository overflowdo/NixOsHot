{ config, pkgs, lib, ... }:

{
    time.timeZone = "Europe/Berlin";
    i18n.defaultLocale = "de_DE.UTF-8";
    console.keyMap = "de";

    networking.hostName = "hot-keyA";

    #User mit Sudo
    users.users.user = {
        isNormalUser = true;
        description = "Admin";
        initialPassword = "changeme";
        extraGroups = [ "wheel" ];
    };

    security.sudo.wheelNeedsPassword = true;

    environment.etc."scripts/wgHMAC_export.sh" = {
        source = ./files/wgHMAC_export.sh;
        mode = "0755";
    };
    environment.etc."scripts/wgPeer_setup.sh" = {
        source = ./files/wgPeer_setup.sh;
        mode = "0755";
    };
    environment.etc."scripts/mnt-USB.sh" = {
        source = ./files/mnt-USB.sh;
        mode   = "0755";
    };
    environment.etc."scripts/format-USB.sh" = {
        source = ./files/format-USB.sh;
        mode   = "0755";
    };
    environment.etc."scripts/delete_seed.sh" = {
        source = ./files/delete_seed.sh;
        mode   = "0755";
    };

    #Wrappers

    environment.etc."scripts/wrappers/wgHMAC_export.sh" = {
        source = ./files/wrappers/wgHMAC_export.sh;
        mode = "0755";
    };
    environment.etc."scripts/wrappers/wgPeer_setup.sh" = {
        source = ./files/wrappers/wgPeer_setup.sh;
        mode = "0755";
    };
    environment.etc."scripts/wrappers/mnt-USB.sh" = {
        source = ./files/wrappers/mnt-USB.sh;
        mode   = "0755";
    };
    environment.etc."scripts/wrappers/format-USB.sh" = {
        source = ./files/wrappers/format-USB.sh;
        mode   = "0755";
    };
    environment.etc."scripts/wrappers/delete_seed.sh" = {
        source = ./files/wrappers/delete_seed.sh;
        mode   = "0755";
    };


    #Desktop page mit symlinks auf wrappers
    #Legt Ordner beim Boot an (oder beim tmpfiles-setup)
    systemd.tmpfiles.rules = [
        "d /home/user/Desktop 0750 user users - -"
        "d /home/user/Desktop/scripts 0750 user users - -"

        "L+ /home/user/Desktop/scripts/wgHMAC_export.sh - - - - /etc/scripts/wrappers/wgHMAC_export.sh"
        "L+ /home/user/Desktop/scripts/wgPeer_setup.sh - - - - /etc/scripts/wrappers/wgPeer_setup.sh"
        "L+ /home/user/Desktop/scripts/format-USB.sh - - - - /etc/scripts/wrappers/format-USB.sh"
        "L+ /home/user/Desktop/scripts/mnt-USB.sh - - - - /etc/scripts/wrappers/mnt-USB.sh"
        "L+ /home/user/Desktop/scripts/delete_seed.sh - - - - /etc/scripts/wrappers/delete_seed.sh"

        #docker
        # Hauptverzeichnis
        "d /psbt-signer 0770 root 1000 -"
        "d /psbt-signer/run/data 0770 root 1000 -"
        "d /psbt-signer/run/wallets 0770 root 1000 -"
        "d /psbt-signer/run/secrets 0770 root 1000 -"

        "d /var/lib/signer 0770 root 1000 - -"
        "d /var/lib/signer/wallets 0770 root 1000 - -"
        "d /var/lib/signer/data 0770 root 1000 - -"
        "d /var/lib/signer/tpm 0770 root 1000 - -"
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