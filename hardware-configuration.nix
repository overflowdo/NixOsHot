{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" ];
  boot.kernelModules = [ "usb_storage" "uas" ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-label/NIXCRYPT";

  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "ext4";
  };

  fileSystems."/boot" = { 
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" "umask=0077" ];
  };

  swapDevices = [ ];
  boot.kernel.sysctl."vm.swappiness" = 0;
  zramSwap.enable = false;

  #USB nur bewusst mounten
  services.udisks2.enable = lib.mkForce false;

}