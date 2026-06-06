#!/usr/bin/env bash
set -euo pipefail

USB_DEVICE="/dev/disk/by-label/USB"
USB_MOUNT="/mnt/usb"

echo "=== USB Export ==="

lsblk

#Formatieren
mkdir -p "$USB_MOUNT"

udo mkfs.ext4 -L USB /dev/sdb

mount "$USB_DEVICE" "$USB_MOUNT"



mkdir -p "$USB_MOUNT/signer"


# HMAC Secret nur erzeugen wenn noch keines existiert
mkdir -p /etc/signer

if [ ! -f /etc/signer/hmac.secret ]; then
    openssl rand -hex 32 > /etc/signer/hmac.secret
    chmod 600 /etc/signer/hmac.secret
fi


# Export
cp \
  /etc/wireguard/public.key \
  "$USB_MOUNT/signer/wireguard-public.key"

cp \
  /etc/signer/hmac.secret \
  "$USB_MOUNT/signer/signer-hmac.secret"

sync

echo ""
echo "Exported:"
echo "  wireguard-public.key"
echo "  signer-hmac.secret"

umount "$USB_MOUNT"