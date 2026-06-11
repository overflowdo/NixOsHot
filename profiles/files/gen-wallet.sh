#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/signer"
INIT_MARKER="${STATE_DIR}/initialized"

mkdir -p "${STATE_DIR}"
chmod 700 "${STATE_DIR}"

if [[ -f "${INIT_MARKER}" ]]; then
    echo "Signer bereits initialisiert."
    exit 0
fi

echo "1. Seed vorbereiten und versiegeln ..."
# 2. 32 Bytes kryptographischer Seed
SEED=$(openssl rand -hex 32)

# 3. TPM Primary Key erzeugen (Storage Hierarchy)
tpm2_createprimary -C o -c "${STATE_DIR}/primary.ctx" >/dev/null

# 4. Seed mit TPM versiegeln
echo -n "${SEED}" | \
    tpm2_create -C "${STATE_DIR}/primary.ctx" \
                -u "${STATE_DIR}/seal.pub" \
                -r "${STATE_DIR}/seal.priv" \
                -i - \
                -c "${STATE_DIR}/sealed.ctx" >/dev/null

echo "Seed im TPM versiegelt."

########################################################################

echo "2. Wallet-Metadaten erzeugen ..."

#switch auf python für bessere erstellung mit bibliotheken
tpm2_unseal -c "${STATE_DIR}/sealed.ctx" | python3 derive_wallet.py


echo "3. Descriptoren registrieren ..."
curl --user user:pass \
  --data-binary '{
    "jsonrpc": "1.0",
    "id": "createwallet",
    "method": "createwallet",
    "params": [
      "keyA",
      false,
      false,
      "",
      false,
      false,
      true
    ]
  }' \
  -H 'content-type: text/plain;' \
  http://192.168.99.101:18443/

DESC_FILE="/var/lib/signer/wallet/descriptor.public.txt"
DESC=$(cat "$DESC_FILE")

curl --user user:pass \
  --data-binary '{
    "jsonrpc": "1.0",
    "id": "importdesc",
    "method": "importdescriptors",
    "params": [[
      {
        "desc": "${DESC}",
        "timestamp": "now",
        "active": true,
        "internal": false,
        "range": [0, 1000]
      }
    ]]
  }' \
  -H 'content-type: text/plain;' \
  http://192.168.99.101:18443/


#Überprüfen
curl --user regtestuser:password \
  --data-binary '{
    "jsonrpc":"1.0",
    "id":"x",
    "method":"getwalletinfo",
    "params":[]
  }' \
  -H 'content-type:text/plain;' \
  http://192.168.99.101:18443/


echo "4. Status schreiben ..."
touch "${INIT_MARKER}"

echo "5. Initialsiert"