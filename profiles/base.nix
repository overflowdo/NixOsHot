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
    
    environment.etc."scripts/export_xpub" = {
        source = ./files/export_xpub.sh;
        mode = "0755";
    };

    environment.etc."scripts/wgHMAC_exporth" = {
        source = ./files/wgHMAC_export.sh;
        mode = "0755";
    };


    #Wrappers
    environment.etc."scripts/wrappers/export_xpub.sh" = {
        source = ./files/wrappers/export_xpub.sh;
        mode = "0755";
    };

    environment.etc."scripts/wrappers/wgHMAC_export.sh" = {
        source = ./files/wrappers/wgHMAC_export.sh;
        mode = "0755";
        
    };


    #Desktop page mit symlinks auf wrappers
    #Legt Ordner beim Boot an (oder beim tmpfiles-setup)
    systemd.tmpfiles.rules = [
        "d /home/user/Desktop 0750 user users - -"
        "d /home/user/Desktop/scripts 0750 user users - -"

        "L+ /home/user/Desktop/scripts/export_xpub.sh - - - - /etc/scripts/wrappers/export_xpub.sh"
        "L+ /home/user/Desktop/scripts/wgHMAC_export.sh - - - - /etc/scripts/wrappers/wgHMAC_export.sh"
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