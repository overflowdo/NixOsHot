#!/usr/bin/env python3

import subprocess
import os
import json
import sys

STATE_DIR = "/var/lib/signer"
os.makedirs(STATE_DIR, exist_ok=True)

# Errechnet den Pfad zu 'scripts/' (ein Ordner über 'setup/')
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.append(PARENT_DIR)

PRIMARY_CTX = os.path.join(STATE_DIR, "primary.ctx")

KEY_CTX = os.path.join(STATE_DIR, "signing_key.ctx")

PUBLIC_KEY_FILE = os.path.join(STATE_DIR, "public_key.pem")

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