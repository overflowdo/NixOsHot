#!/usr/bin/env python3

import json
import subprocess
from pathlib import Path

import requests

STATE_DIR = "/var/lib/signer/state"
DESC_FILE = "/var/lib/signer/wallet/descriptor.public.txt"

RPC_USER = "user"
RPC_PASSWORD = "pass"
RPC_HOST = "192.168.99.101"
RPC_PORT = 18443

RPC_URL = f"http://{RPC_HOST}:{RPC_PORT}"
WALLET_RPC_URL = f"{RPC_URL}/wallet/keyA"


def rpc_call(url, method, params=None, rpc_id="python"):
    payload = {
        "jsonrpc": "1.0",
        "id": rpc_id,
        "method": method,
        "params": params or []
    }

    response = requests.post(
        url,
        auth=(RPC_USER, RPC_PASSWORD),
        json=payload,
        headers={"content-type": "text/plain;"}
    )

    response.raise_for_status()

    result = response.json()

    if result.get("error") is not None:
        raise RuntimeError(
            f"RPC-Fehler bei '{method}': {result['error']}"
        )

    return result["result"]


print("2. Wallet-Metadaten erzeugen ...")

# tpm2_unseal ausführen
unseal = subprocess.run(
    [
        "tpm2_unseal",
        "-c",
        f"{STATE_DIR}/sealed.ctx"
    ],
    capture_output=True,
    check=True
)

# Ausgabe an derive_wallet.py übergeben
subprocess.run(
    ["python3", "derive_wallet.py"],
    input=unseal.stdout,
    check=True
)

print("3. Descriptoren registrieren ...")

# Wallet erzeugen
rpc_call(
    RPC_URL,
    "createwallet",
    [
        "keyA",
        False,
        False,
        "",
        False,
        True
    ],
    rpc_id="createwallet"
)

# Descriptor laden
desc = Path(DESC_FILE).read_text().strip()

# Descriptor mit Checksum versehen
desc_info = rpc_call(
    RPC_URL,
    "getdescriptorinfo",
    [desc],
    rpc_id="checksum"
)

desc = desc_info["descriptor"]

# Descriptor importieren
rpc_call(
    WALLET_RPC_URL,
    "importdescriptors",
    [[
        {
            "desc": desc,
            "timestamp": "now",
            "active": True,
            "internal": False,
            "range": [0, 1000]
        }
    ]],
    rpc_id="importdesc"
)

# Wallet prüfen
wallet_info = rpc_call(
    WALLET_RPC_URL,
    "getwalletinfo",
    [],
    rpc_id="x"
)

print("\nWallet erfolgreich eingerichtet:")
print(json.dumps(wallet_info, indent=2))