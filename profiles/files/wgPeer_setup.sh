#!/usr/bin/env bash
set -euo pipefail

USB_MOUNT="/mnt/usb"
WG_IF="wg0"

WG_JSON="$USB_MOUNT/communication/wireguard/wireguard.wallet.json"

mkdir -p "$USB_MOUNT"
if mountpoint -q "$USB_MOUNT"; then
  echo "USB already mounted at $USB_MOUNT, skipping mount"
else
  echo "Mounting USB..."
  mount "$USB_DEVICE" "$USB_MOUNT"
fi

if [[ ! -f "$WG_JSON" ]]; then
    echo "ERROR: wireguard.wallet.json not found on USB" >&2
    exit 1
fi


if ! ip link show "$WG_IF" >/dev/null 2>&1; then
    echo "ERROR: WireGuard interface $WG_IF not found" >&2
    exit 1
fi


SIGNER_PUB_KEY=$(jq -r '.signer_public_key' "$WG_JSON")
SIGNER_IP=$(jq -r '.signer_ip' "$WG_JSON")

if [[ -z "$SIGNER_PUB_KEY" || "$SIGNER_PUB_KEY" == "null" ]]; then
    echo "ERROR: invalid signer_public_key" >&2
    exit 1
fi

if [[ -z "$SIGNER_IP" || "$SIGNER_IP" == "null" ]]; then
    echo "ERROR: invalid signer_ip" >&2
    exit 1
fi

#normalize CIDR -> /32 for peer
ALLOWED_IP="${SIGNER_IP%/*}/32"

echo "Applying WireGuard peer..."
echo "Peer: $SIGNER_PUB_KEY"
echo "AllowedIPs: $ALLOWED_IP"

#Remove existing peer (only one allowed for specific wallet signer)
wg set "$WG_IF" peer "$SIGNER_PUB_KEY" remove 2>/dev/null || true

#add peer
KEEPALIVE=25

wg set "$WG_IF" peer "$SIGNER_PUB_KEY" \
    allowed-ips "$ALLOWED_IP" \
    persistent-keepalive "$KEEPALIVE"

echo "WireGuard peer applied successfully."