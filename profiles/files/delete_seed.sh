#!/usr/bin/env bash
set -euo pipefail

SEED_FILE="${HOME:-/home/user}/Desktop/SEED_PHRASE.txt"

if [[ -f "$SEED_FILE" ]]; then
  chmod u+w "$SEED_FILE" 2>/dev/null || true   # 0400 -> zum Überschreiben beschreibbar
  if command -v shred >/dev/null 2>&1; then
    shred -u "$SEED_FILE"
  else
    rm -f "$SEED_FILE"
  fi
  echo "Seed-Datei sicher gelöscht: $SEED_FILE"
else
  echo "Keine Seed-Datei gefunden ($SEED_FILE) – nichts zu tun."
fi