#!/usr/bin/env bash
set -euo pipefail

DISK="/dev/sda"
EFI_SIZE="1024M"

REPO_URL="https://github.com/overflowdo/NixOsHot.git"
REPO_SUBDIR=""
SWAP_SIZE_GB="2"

# Robust partition naming
part1="${DISK}1"
part2="${DISK}2"
if [[ "$DISK" =~ nvme ]]; then
  part1="${DISK}p1"
  part2="${DISK}p2"
fi

echo "[1/9] Check disk exists: $DISK"
lsblk "$DISK" >/dev/null

echo "[2/9] Partitioning $DISK (GPT + EFI + ROOT)"
sgdisk --zap-all "$DISK"
sgdisk -og "$DISK"
sgdisk -n 1:0:+"$EFI_SIZE" -t 1:ef00 -c 1:"NIXBOOT" "$DISK"
sgdisk -n 2:0:0           -t 2:8300 -c 2:"NIXROOT" "$DISK"
partprobe "$DISK"
udevadm trigger
udevadm settle
sleep 2

ensure_nixboot() {
  local part="$part1"
  [[ -b "$part" ]] || { echo "ERROR: $part not found"; exit 1; }

  local fstype label
  fstype="$(blkid -o value -s TYPE "$part" 2>/dev/null || true)"
  label="$(blkid -o value -s LABEL "$part" 2>/dev/null || true)"

  if [[ "$fstype" == "vfat" && "$label" == "NIXBOOT" ]]; then
    echo "[OK] NIXBOOT already present on $part"
    return 0
  fi

  echo "[DO] Creating/refreshing NIXBOOT on $part (fstype=$fstype label=$label)"
  mkfs.fat -F 32 -n NIXBOOT "$part"
}

ensure_nixroot() {
  local part="$part2"
  [[ -b "$part" ]] || { echo "ERROR: $part not found"; exit 1; }

  local fstype label
  fstype="$(blkid -o value -s TYPE "$part" 2>/dev/null || true)"
  label="$(blkid -o value -s LABEL "$part" 2>/dev/null || true)"

  if [[ "$fstype" == "ext4" && "$label" == "NIXROOT" ]]; then
    echo "[OK] NIXROOT already present on $part"
    return 0
  fi

  echo "[DO] Creating/refreshing NIXROOT on $part (fstype=$fstype label=$label)"
  mkfs.ext4 -F -L NIXROOT "$part"
}

echo "[3/9] Formatting partitions (FAT32 EFI + EXT4 root)"
ensure_nixboot
ensure_nixroot

partprobe "$DISK"
udevadm trigger
udevadm settle
sleep 1

echo "[4/9] Mounting"
mountpoint -q /mnt && umount -R /mnt || true
mount /dev/disk/by-label/NIXROOT /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/NIXBOOT /mnt/boot

echo "[5/9] Creating swapfile (${SWAP_SIZE_GB}G)"
if [[ ! -f /mnt/.swapfile ]]; then
  fallocate -l "${SWAP_SIZE_GB}G" /mnt/.swapfile
  chmod 600 /mnt/.swapfile
  mkswap /mnt/.swapfile
fi
swapon /mnt/.swapfile || true

echo "[6/9] Generate hardware config"
nixos-generate-config --root /mnt

echo "[7/9] Replace /mnt/etc/nixos with repo content"
rm -rf /mnt/etc/nixos/*
mkdir -p /mnt/etc/nixos

git clone --depth 1 "$REPO_URL" /mnt/etc/nixos/.repo

if [[ -n "$REPO_SUBDIR" ]]; then
  if [[ ! -d "/mnt/etc/nixos/.repo/$REPO_SUBDIR" ]]; then
    echo "ERROR: Repo subdir not found: $REPO_SUBDIR"
    echo "Repo content:"
    ls -la /mnt/etc/nixos/.repo
    exit 1
  fi
  cp -a "/mnt/etc/nixos/.repo/$REPO_SUBDIR/." /mnt/etc/nixos/
else
  cp -a /mnt/etc/nixos/.repo/. /mnt/etc/nixos/
fi

rm -rf /mnt/etc/nixos/.repo
rm -rf /etc/nixos/.git


echo "[9/9] Install NixOS"
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-install --no-root-passwd --flake /mnt/etc/nixos#hot

echo "DONE. Remove ISO in Proxmox and reboot."