#!/usr/bin/env bash
set -euo pipefail

USB_DEVICE="/dev/disk/by-label/USB"
USB_MOUNT="/mnt/usb"

echo "=== USB Export ==="

lsblk

#Formatieren
mkdir -p "$USB_MOUNT"

mount "$USB_DEVICE" "$USB_MOUNT"



mkdir -p "$USB_MOUNT/communication"

# --------------------------------------------------
# sanity checks
# --------------------------------------------------

test -f /etc/wireguard/public.key
test -f /etc/signer/hmac.secret
test -f /etc/signer/hot-wallet.xpub

# optional
MASTER_FINGERPRINT_FILE="/etc/signer/master-fingerprint"
DERIVATION_FILE="/etc/signer/derivation-path"

# --------------------------------------------------
# export raw files
# --------------------------------------------------

cp \
  /etc/wireguard/public.key \
  "$USB_MOUNT/communication/wireguard-public.key"

cp \
  /etc/signer/hmac.secret \
  "$USB_MOUNT/communication/signer-hmac.secret"

cp \
  /etc/signer/hot/hot-wallet.xpub \
  "$USB_MOUNT/wallet/hot/hot-wallet.xpub"

# --------------------------------------------------
# metadata
# --------------------------------------------------

XPUB=$(cat /etc/signer/hot-wallet.xpub)

MASTER_FINGERPRINT="unknown"
DERIVATION="unknown"

if [ -f "$MASTER_FINGERPRINT_FILE" ]; then
    MASTER_FINGERPRINT=$(cat "$MASTER_FINGERPRINT_FILE")
fi

if [ -f "$DERIVATION_FILE" ]; then
    DERIVATION=$(cat "$DERIVATION_FILE")
fi

cat > "$USB_MOUNT/wallet/hot/wallet.json" <<EOF
{
  "wallet_name": "hot",
  "network": "regtest",
  "master_fingerprint": "${MASTER_FINGERPRINT}",
  "derivation": "${DERIVATION}",
  "xpub": "${XPUB}"
}
EOF

sync

echo ""
echo "Export complete"
echo ""
echo "Files:"
echo "  communication/wireguard-public.key"
echo "  communication/signer-hmac.secret"
echo "  wallet/hot-wallet.xpub"
echo "  wallet/wallet.json"

umount "$USB_MOUNT"