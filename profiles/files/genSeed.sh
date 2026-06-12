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


echo "4. Status schreiben ..."
touch "${INIT_MARKER}"

echo "5. Initialsiert"