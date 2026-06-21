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

# Fallback defaults (fallback)
SIGNER_IP="10.10.0.2/32"
WALLET_IP="10.10.0.1/32"

# robust endpoint
if [[ -z "${SIGNER_ENDPOINT_IP:-}" ]]; then
  SIGNER_ENDPOINT_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
fi


WG_PORT="51820"
WG_ENDPOINT="${SIGNER_ENDPOINT_IP}:${WG_PORT}"

SIGNER_WG_PUB="/var/lib/wireguard/public.key"

SIGNER_PUB_KEY="$(cat "$SIGNER_WG_PUB")"

WIREGUARD_JSON="$USB_MOUNT/communication/wireguard/wireguard.signer.json"

mkdir -p "$(dirname "$WIREGUARD_JSON")"

cat > "$WIREGUARD_JSON" <<EOF
{
  "signer_public_key": "$SIGNER_PUB_KEY",
  "signer_ip": "$SIGNER_IP",
  "wallet_ip": "$WALLET_IP",
  "port": $WG_PORT,
  "endpoint": "$WG_ENDPOINT",
  "allowed_ips_signer": "$WALLET_IP",
  "allowed_ips_wallet": "$SIGNER_IP"
}
EOF

chmod 644 "$WIREGUARD_JSON"

echo "Exported: wireguard.signer.json"




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
echo "Unmount USB"

umount "$USB_MOUNT"