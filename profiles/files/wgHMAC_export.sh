#!/usr/bin/env bash
set -euo pipefail

USB_DEVICE="/dev/disk/by-label/USB"
USB_MOUNT="/mnt/usb"


#Mount
command -v lsblk >/dev/null
command -v mount >/dev/null
command -v cp >/dev/null

if [[ ! -b "$USB_DEVICE" ]]; then
  echo "ERROR: USB device not found: $USB_DEVICE" >&2
  exit 1
fi

mkdir -p "$USB_MOUNT"

if mountpoint -q "$USB_MOUNT"; then
  echo "USB already mounted at $USB_MOUNT, skipping mount"
else
  echo "Mounting USB..."
  mount "$USB_DEVICE" "$USB_MOUNT"
fi


#Dir setup USB
cleanup() {
  echo "Cleaning up..."
  sync || true
  umount "$USB_MOUNT" 2>/dev/null || true
}
trap cleanup EXIT


mkdir -p "$USB_MOUNT/communication"
mkdir -p "$USB_MOUNT/wallet/hot"

#File test
FILES=(
  "/var/lib/wireguard/public.key"
  "/var/lib/signer/hmac.secret"
  "/var/lib/signer/wallets/xpub.txt"
  "/var/lib/signer/wallets/descriptor.public.txt"
  "/var/lib/signer/wallets/metadata.json"
)

for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing file: $f" >&2
    exit 1
  fi
done

# optional



# export raw files

# wg
cp \
  /var/lib/wireguard/public.key \
  "$USB_MOUNT/communication/wireguard-public.key"

#API
cp /var/lib/signer/hmac.secret \
  "$USB_MOUNT/communication/signer-hmac.secret"


# Btc-wallet
cp /var/lib/signer/wallets/xpub.txt \
  "$USB_MOUNT/wallet/hot/xpub.txt"
cp /var/lib/signer/wallets/descriptor.public.txt \
  "$USB_MOUNT/wallet/hot/descriptor.public.txt"
cp /var/lib/signer/wallets/metadata.json \
  "$USB_MOUNT/wallet/hot/metadata.json"


echo ""
echo "Export complete"
echo ""
echo "Files:"
echo "  communication/wireguard-public.key"
echo "  communication/hmac.secret"
echo "  wallet/hot/descriptor.public.txt"
echo "  wallet/hot/metadata.json"
echo ""
echo "Unmount USB"

umount "$USB_MOUNT"