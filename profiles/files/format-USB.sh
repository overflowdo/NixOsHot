#!/usr/bin/env bash
set -euo pipefail

DEV="${1:?Usage: format-USB.sh /dev/disk/by-id/<DEIN-STICK>}"
echo "Zielgerät:"
lsblk -no NAME,SIZE,MODEL,LABEL "$DEV"
read -rp "ALLE Daten auf $DEV unwiderruflich löschen? Tippe YES: " ok
[ "$ok" = "YES" ] || { echo "Abgebrochen."; exit 1; }

mkfs.ext4 -L USB "$DEV"
echo "USB formatiert und als 'USB' gelabelt."