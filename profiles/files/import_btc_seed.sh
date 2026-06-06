#!/usr/bin/env bash
set -euo pipefail

USB_MOUNT="/mnt/usb"
SEED_TARGET="/tmp/btc_seed.bin"
TPM_DIR="/var/lib/tpm"
SEALED_OUT="${TPM_DIR}/bitcoin-sealed.bin"

echo "[1] Mount USB..."

lsblk
mkdir -p "$USB_MOUNT"
mount /dev/sdX1 "$USB_MOUNT"   # <-- anpassen

echo "[2] Copy Bitcoin seed..."

cp "$USB_MOUNT/master_seed.bin" "$SEED_TARGET"
chmod 600 "$SEED_TARGET"

echo "[3] Initialize TPM primary key..."

tpm2_createprimary -C o -c primary.ctx

echo "[4] Seal Bitcoin seed into TPM..."

tpm2_create \
  -C primary.ctx \
  -u key.pub \
  -r key.priv

tpm2_seal \
  -c primary.ctx \
  -i "$SEED_TARGET" \
  -o "$SEALED_OUT"

echo "[5] Cleanup plaintext seed..."

shred -u "$SEED_TARGET"
umount "$USB_MOUNT"

echo "[OK] Bitcoin seed secured in TPM."