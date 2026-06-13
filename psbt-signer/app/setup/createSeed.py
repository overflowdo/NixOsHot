#!/usr/bin/env python3

import subprocess
import os
import json
import sys
from embit.ec import PublicKey

STATE_DIR = "/var/lib/signer"
os.makedirs(STATE_DIR, exist_ok=True)

# Errechnet den Pfad zu 'scripts/' (ein Ordner über 'setup/')
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.append(PARENT_DIR)

PRIMARY_CTX = os.path.join(STATE_DIR, "primary.ctx")

KEY_CTX = os.path.join(STATE_DIR, "signing_key.ctx")

PUBLIC_KEY_FILE = os.path.join(STATE_DIR, "public_key.pem")
DESCRIPTOR_FILE = os.path.join(STATE_DIR, "descriptor.public.txt")
METADATA_FILE = os.path.join(STATE_DIR, "metadata.json")

print("Creating TPM primary key...")

subprocess.run([
    "tpm2_createprimary",
    "-C", "o",
    "-g", "sha256",
    "-G", "ecc",
    "-c", PRIMARY_CTX
], check=True)

print("Creating NON-EXPORTABLE signing key inside TPM...")

# KEY IS CREATED INSIDE TPM AND NEVER EXPORTED
subprocess.run([
    "tpm2_create",
    "-C", PRIMARY_CTX,
    "-G", "ecc",
    "-u", os.path.join(STATE_DIR, "key.pub"),
    "-r", os.path.join(STATE_DIR, "key.priv"),
    "-c", KEY_CTX
], check=True)

print("Loading persistent key...")

result = subprocess.run([
    "tpm2_evictcontrol",
    "-C", "o",
    "-c", KEY_CTX
], capture_output=True, text=True, check=True)

print("Extracting PUBLIC KEY ONLY...")

# export public key only
subprocess.run([
    "tpm2_readpublic",
    "-c", KEY_CTX,
    "-f", "pem",
    "-o", PUBLIC_KEY_FILE
], check=True)

with open(os.path.join(STATE_DIR, "metadata.json"), "w") as f:
    json.dump({
        "tpm_key": "ecc",
        "model": "hsm-native",
        "public_key_file": PUBLIC_KEY_FILE,
        "note": "no seed, no xprv, TPM-only key"
    }, f, indent=2)

print("OK: TPM native key created")



#pub descitpor für sparrow multisig


with open(PUBLIC_KEY_FILE, "r") as f:
    pem = f.read()

pub = PublicKey.from_pem(pem)

fingerprint = pub.hash160()[:4].hex()


descriptor = f"wpkh({pub.to_string()})"

with open(DESCRIPTOR_FILE, "w") as f:
    f.write(descriptor)


metadata = {
    "wallet_type": "tpm-native",
    "network": "regtest",
    "model": "hsm-native",

    "fingerprint": fingerprint,

    "keys": [
        {
            "type": "single-sig",
            "format": "wpkh",
            "pubkey": pub.to_string(),
            "pem_file": PUBLIC_KEY_FILE
        }
    ],

    "descriptor_file": DESCRIPTOR_FILE,

    "note": "no seed, no xprv, TPM-only key"
}

with open(METADATA_FILE, "w") as f:
    json.dump(metadata, f, indent=2)

print("OK: TPM native wallet created")
print("Descriptor:", descriptor)