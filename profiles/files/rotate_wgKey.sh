#!/usr/bin/env bash
# Rotiert das WireGuard-Keypair der Key-A-VM (Interface wg0):
#   - erzeugt neuen Private/Public-Key
#   - sichert die alten Keys (timestamped)
#   - schreibt die neuen Keys in die von NixOS gelesene Key-Datei
#   - schreibt PrivateKey zusätzlich in /etc/wireguard/wg0.conf (falls vorhanden)
#   - wendet den neuen Key live auf wg0 an (bestehende Peers bleiben erhalten)
set -euo pipefail

IFACE="wg0"
KEYDIR="/var/lib/wireguard"
PRIV="$KEYDIR/private.key"
PUB="$KEYDIR/public.key"
CONF="/etc/wireguard/wg0.conf"
BACKUP_DIR="$KEYDIR/backup"

[ "$(id -u)" -eq 0 ] || { echo "Bitte als root ausführen (sudo/pkexec)." >&2; exit 1; }
command -v wg >/dev/null || { echo "FEHLER: wireguard-tools (wg) nicht gefunden." >&2; exit 1; }

# Sicherheitsabfrage – Rotation bricht den Tunnel, bis der Peer den neuen Public-Key hat
if [ "${1:-}" != "-y" ]; then
  echo "ACHTUNG: Die Rotation ändert den Public-Key dieser VM."
  echo "Der Tunnel zum Basissystem bleibt unterbrochen, bis dort der neue"
  echo "Public-Key als Peer hinterlegt wurde (siehe Hinweis am Ende)."
  read -rp "WireGuard-Credentials auf '$IFACE' jetzt rotieren? Tippe YES: " ok
  [ "$ok" = "YES" ] || { echo "Abgebrochen."; exit 1; }
fi

umask 077
mkdir -p "$KEYDIR" "$BACKUP_DIR"

# 1) Alte Keys sichern
ts="$(date +%Y%m%d-%H%M%S)"
for f in "$PRIV" "$PUB"; do
  [ -f "$f" ] && cp -a "$f" "$BACKUP_DIR/$(basename "$f").$ts.bak"
done
[ -f "$CONF" ] && cp -a "$CONF" "$BACKUP_DIR/wg0.conf.$ts.bak"

# 2) Neues Keypair erzeugen (atomar über tmp)
new_priv="$(wg genkey)"
new_pub="$(printf '%s' "$new_priv" | wg pubkey)"

tmp_priv="$(mktemp "$KEYDIR/.priv.XXXXXX")"
tmp_pub="$(mktemp "$KEYDIR/.pub.XXXXXX")"
printf '%s\n' "$new_priv" > "$tmp_priv"
printf '%s\n' "$new_pub"  > "$tmp_pub"
chmod 600 "$tmp_priv"; chmod 644 "$tmp_pub"
mv -f "$tmp_priv" "$PRIV"
mv -f "$tmp_pub"  "$PUB"

# 3) In wg0.conf schreiben (nur PrivateKey im [Interface]-Block), falls vorhanden
if [ -f "$CONF" ]; then
  if grep -qE '^\s*PrivateKey\s*=' "$CONF"; then
    sed -i -E "s|^\s*PrivateKey\s*=.*|PrivateKey = ${new_priv}|" "$CONF"
  else
    echo "WARNUNG: keine PrivateKey-Zeile in $CONF gefunden – nicht verändert." >&2
  fi
  chmod 600 "$CONF"
fi

# 4) Live auf das Interface anwenden (Peers bleiben erhalten)
if wg show "$IFACE" >/dev/null 2>&1; then
  wg set "$IFACE" private-key "$PRIV"
  echo "[*] Neuer Private-Key live auf $IFACE gesetzt."
else
  echo "WARNUNG: $IFACE ist nicht aktiv – Key nur in Dateien geschrieben." >&2
  echo "         Aktivieren mit: systemctl restart wireguard-${IFACE}.service" >&2
fi

echo
echo "==================================================================="
echo "Rotation abgeschlossen. NEUER PUBLIC-KEY (an das Basissystem geben):"
echo
echo "    $new_pub"
echo
echo "Nächste Schritte:"
echo "  1) Public-Key exportieren:  /home/user/Desktop/scripts/wgHMAC_export.sh"
echo "  2) Auf dem Basissystem den Peer mit diesem neuen Public-Key aktualisieren."
echo "  3) Verbindung prüfen:  sudo wg show   (siehe 'latest handshake')"
echo "Backup der alten Keys: $BACKUP_DIR"
echo "==================================================================="