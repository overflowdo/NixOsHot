import subprocess
import json
import os
import sys

# Errechnet den Pfad zu 'scripts/' (ein Ordner über 'setup/')
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.append(PARENT_DIR)

PUBLIC_KEY_FILE = "/var/lib/signer/public_key.pem"

with open(PUBLIC_KEY_FILE) as f:
    pubkey = f.read().strip()

descriptor = f"wpkh({pubkey})"

rpc = [
    "bitcoin-cli",
    "-regtest",
    "importdescriptors",
    json.dumps([{
        "desc": descriptor,
        "timestamp": "now"
    }])
]

subprocess.run(rpc, check=True)

print("Wallet registered in Bitcoin Core regtest")