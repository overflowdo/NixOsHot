#!/usr/bin/env bash
set -euo pipefail

USB_MOUNT="/mnt/usb"
USB_DEVICE="/dev/disk/by-label/USB"

SEED_TARGET="/tmp/btc_seed.bin"

TPM_DIR="/var/lib/tpm"

SEALED_OUT="${TPM_DIR}/bitcoin-sealed.bin"

SIGNER_DIR="/etc/signer"

echo "[1] Mount USB..."

mkdir -p "$USB_MOUNT"
mount "$USB_DEVICE" "$USB_MOUNT"

echo "[2] Verify files..."

test -f "$USB_MOUNT/hot/master_seed.bin"
test -f "$USB_MOUNT/hot/hot-wallet.xpub"
test -f "$USB_MOUNT/hot/master-fingerprint.txt"
test -f "$USB_MOUNT/hot/derivation-path.txt"

mkdir -p "$SIGNER_DIR"

echo "[3] Copy seed..."

cp "$USB_MOUNT/hot/master_seed.bin" "$SEED_TARGET"
chmod 600 "$SEED_TARGET"

echo "[4] Store wallet metadata..."

cp \
  "$USB_MOUNT/hot/hot-wallet.xpub" \
  "$SIGNER_DIR/hot-wallet.xpub"

cp \
  "$USB_MOUNT/hot/master-fingerprint.txt" \
  "$SIGNER_DIR/master-fingerprint"

cp \
  "$USB_MOUNT/hot/derivation-path.txt" \
  "$SIGNER_DIR/derivation-path"

chmod 600 "$SIGNER_DIR/"*

echo "[5] Initialize TPM..."

tpm2_createprimary -C o -c primary.ctx

echo "[6] Seal seed..."

tpm2_seal \
  -c primary.ctx \
  -i "$SEED_TARGET" \
  -o "$SEALED_OUT"

echo "[7] Cleanup..."

shred -u "$SEED_TARGET"

HOT_DIR="$USB_MOUNT/hot"

if [ -d "$HOT_DIR" ]; then
    find "$HOT_DIR" -type f -exec shred -u {} \;

    # remove empty directory tree
    rm -rf "$HOT_DIR"
fi

umount "$USB_MOUNT"

echo "[OK] Bitcoin seed secured in TPM."
echo "[OK] Wallet metadata installed."