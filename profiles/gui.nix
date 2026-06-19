{ config, pkgs, ... }:

{
  services.xserver.enable = true;

  # Solide, leichtgewichtig für VM/noVNC
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };
}