#!/usr/bin/env bash
set -euo pipefail

TARGET="/etc/scripts/mnt-USB.sh"

# echte Pfade auflösen
SELF_REAL="$(readlink -f "$0")"
TARGET_REAL="$(readlink -f "$TARGET")"

# Rekursionsschutz
if [[ "$SELF_REAL" == "$TARGET_REAL" ]]; then
  echo "ERROR: Wrapper ruft sich selbst auf (Rekursion)."
  echo "SELF=$SELF_REAL"
  echo "TARGET=$TARGET_REAL"
  exit 1
fi

#Existenz / ausführbar prüfen
if [[ ! -x "$TARGET_REAL" ]]; then
  echo "ERROR: Zielscript fehlt oder ist nicht ausführbar: $TARGET_REAL"
  echo "Tipp: chmod +x '$TARGET_REAL'"
  exit 1
fi

# Root-Abfrage + Terminal offen lassen + sichtbares Feedback
exec xfce4-terminal --hold --command \
  "bash -lc '\"$TARGET_REAL\"; echo; read -n1 -rsp \"Taste zum Schließen…\"'"