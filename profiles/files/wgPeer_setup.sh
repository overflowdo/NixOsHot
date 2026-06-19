#!/usr/bin/env bash
set -euo pipefail

USB_DEVICE="/dev/disk/by-label/USB"
USB_MOUNT="/mnt/usb"
WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/$WG_IF.conf"

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


WALLET_PUB_KEY=$(jq -r '.wallet_public_key' "$WG_JSON")
WALLET_IP=$(jq -r '.wallet_ip' "$WG_JSON")

if [[ -z "$WALLET_PUB_KEY" || "$WALLET_PUB_KEY" == "null" ]]; then
    echo "ERROR: invalid wallet_public_key" >&2
    exit 1
fi

if [[ -z "$WALLET_IP" || "$WALLET_IP" == "null" ]]; then
    echo "ERROR: invalid wallet_ip" >&2
    exit 1
fi

ALLOWED_IP="${WALLET_IP%/*}/32"

echo "Applying WireGuard peer..."
echo "Peer: $WALLET_PUB_KEY"
echo "AllowedIPs: $ALLOWED_IP"

#Konfig datei neuschreiben oder Peer überschreiben

    
# Verzeichnis mit sicheren Rechten erstellen
mkdir -p "$(dirname "$WG_CONF")"
chmod 700 "$(dirname "$WG_CONF")"

PRIVATE_KEY_FILE="/var/lib/wireguard/private.key"
if [[ -f "$PRIVATE_KEY_FILE" ]]; then
    PRIV_KEY=$(cat "$PRIVATE_KEY_FILE")
else
    echo "ERROR: Private key file $PRIVATE_KEY_FILE not found!" >&2
    exit 1
fi

# überschreiben
cat <<EOF > "$WG_CONF"
[Interface]
Address = 10.10.0.2/32
PrivateKey = $PRIV_KEY
ListenPort = 34698
SaveConfig = true

[Peer]
PublicKey = $WALLET_PUB_KEY
AllowedIPs = $ALLOWED_IP
PersistentKeepalive = 25
EOF

chmod 600 "$WG_CONF"


wg set "$WG_IF" peer "$WALLET_PUB_KEY" remove 2>/dev/null || true


KEEPALIVE=25
wg set "$WG_IF" peer "$WALLET_PUB_KEY" \
    allowed-ips "$ALLOWED_IP" \
    persistent-keepalive "$KEEPALIVE"

echo "WireGuard peer applied successfully."