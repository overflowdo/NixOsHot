#!/usr/bin/env bash
set -euo pipefail
sudo mount /dev/disk/by-label/USB /mnt/usb
sudo chown -R "${SUDO_USER:-$USER}:users" /mnt/usb
echo "USB drive mounted at /mnt/usb"