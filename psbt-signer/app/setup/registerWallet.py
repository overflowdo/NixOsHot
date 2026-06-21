#!/usr/bin/env python3

import os
import json
from pathlib import Path

import requests

STATE_DIR = "/psbt-signer/run/state"
DESC_FILE = "/psbt-signer/run/wallets/descriptor.public.txt"

RPC_USER = "user"
RPC_PASSWORD = "pass"
RPC_HOST = os.getenv("BTC-NETWORK_IP", "192.168.99.58")
RPC_PORT = os.getenv("BTC-NETWORK_PORT", 18443)

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

    # Zuerst versuchen, die JSON-Fehlermeldung von Bitcoin Core zu lesen
    try:
        result = response.json()
        if result.get("error") is not None:
            raise RuntimeError(
                f"RPC-Fehler bei '{method}': {result['error']}"
            )
        return result["result"]
    except ValueError:
        #error 500
        response.raise_for_status()
        raise



print("3. Descriptoren registrieren ...")
print("createwallet in regtest")
# Wallet erzeugen
rpc_call(
    RPC_URL,
    "createwallet",
    [
        "keyA",
        True,   #Disable priv keys
        True,   #blank wallet
        "",
        False,
        True    #descriptor (neu)
    ],
    rpc_id="createwallet"
)

# Descriptor laden
desc = Path(DESC_FILE).read_text().strip()

print("load descriptor checksum")
# Descriptor mit Checksum versehen
desc_info = rpc_call(
    RPC_URL,
    "getdescriptorinfo",
    [desc],
    rpc_id="checksum"
)

desc = desc_info["descriptor"]
# Externer (/0/*)
external_desc = desc

# Interner Change-Descriptor (/1/*)
internal_desc = desc.replace("/0/*", "/1/*")

print("Import descriptor with checksum")
# Descriptor importieren
rpc_call(
    WALLET_RPC_URL,
    "importdescriptors",
    [[
        {
            "desc": external_desc,
            "timestamp": "now",
            "active": True,
            "internal": False,
            "keypool": True,
            "range": [0, 1000]
        },
        {
            "desc": internal_desc,
            "timestamp": "now",
            "active": True,
            "internal": True,
            "keypool": True,
            "range": [0, 1000]
        }
    ]],
    rpc_id="importdesc"
)

print("Done")
print("GetWalletInfo")
# Wallet prüfen
wallet_info = rpc_call(
    WALLET_RPC_URL,
    "getwalletinfo",
    [],
    rpc_id="x"
)

print("\nWallet erfolgreich eingerichtet:")
print(json.dumps(wallet_info, indent=2))