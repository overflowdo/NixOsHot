#!/usr/bin/env bash
set -euo pipefail

DEVICE="/dev/sdX"
MOUNT="/mnt/bootstrap"

WG_DIR="/etc/wireguard"
SIGNER_SECRET_DIR="/etc/signer"

echo "[1] Wipe USB device"

wipefs -a "$DEVICE"

parted "$DEVICE" --script mklabel gpt
parted "$DEVICE" --script mkpart primary ext4 0% 100%

mkfs.ext4 "${DEVICE}1"

mkdir -p "$MOUNT"
mount "${DEVICE}1" "$MOUNT"

echo "[2] Generate WireGuard keys (Signer)"

mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

wg genkey | tee "${WG_DIR}/private.key" | wg pubkey > "${WG_DIR}/public.key"

chmod 600 "${WG_DIR}/private.key"
chmod 644 "${WG_DIR}/public.key"

echo "[3] Generate HMAC API secret"

mkdir -p "$SIGNER_SECRET_DIR"

openssl rand -hex 32 > "${SIGNER_SECRET_DIR}/api.key"

chmod 600 "${SIGNER_SECRET_DIR}/api.key"

echo "[4] Export bootstrap material to USB"

cp "${WG_DIR}/public.key" \
   "${MOUNT}/signer_wg_public.key"

cp "${SIGNER_SECRET_DIR}/api.key" \
   "${MOUNT}/signer_api_secret.txt"

echo "[5] Metadata"

cat > "${MOUNT}/bootstrap.json" <<EOF
{
  "created_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contains": [
    "signer_wg_public.key",
    "signer_api_secret.txt"
  ]
}
EOF

sync

umount "$MOUNT"

echo
echo "Bootstrap medium created."
echo
echo "USB contains:"
echo "  signer_wg_public.key"
echo "  signer_api_secret.txt"