#!/usr/bin/env python3
import os
import sys
import subprocess
from embit import bip39

STATE_DIR = "/var/lib/signer"
INIT_MARKER = os.path.join(STATE_DIR, "initialized")

def main():

    os.makedirs(STATE_DIR, exist_ok=True)
    os.chmod(STATE_DIR, 0o700)

    if os.path.exists(INIT_MARKER):
        print("Signer bereits initialisiert.")
        sys.exit(0)


    print("1. Mnemonic Phrase (24 Wörter) generieren...")
    # Entropy erzeugen
    entropy = os.urandom(32)
    # In BIP-39 Wörter umwandeln
    mnemonic_phrase = bip39.mnemonic_from_bytes(entropy)
    
    del entropy

    print("TPM Primary Key")
    primary_ctx = os.path.join(STATE_DIR, "primary.ctx")
    subprocess.run([
        "tpm2_createprimary", "-C", "o", "-c", primary_ctx
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print("versiegeln")
    seal_pub = os.path.join(STATE_DIR, "seal.pub")
    seal_priv = os.path.join(STATE_DIR, "seal.priv")
    sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")

    #TPM an PCR binden für sicherheit
    policy_file = "/var/lib/signer/pcr.policy"

    subprocess.run([
        "tpm2_policypcr",
        "-l", "sha256:7",
        "-L", policy_file
    ], check=True)


    process = subprocess.Popen([
        "tpm2_create", 
        "-C", primary_ctx,
        "-u", seal_pub,
        "-r", seal_priv,
        "-L", policy_file,
        "-i", "-",
        "-c", sealed_ctx
    ], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    # Daten einspeisen und ausführen
    _, stderr = process.communicate(input=mnemonic_phrase.encode('utf-8'))

    if process.returncode != 0:
        print(f"Fehler beim Versiegeln im TPM: {stderr.decode()}", file=sys.stderr)
        sys.exit(1)


    del mnemonic_phrase


    with open(INIT_MARKER, "w") as f:
        f.write("1")

    print("Mnemonic im TPM versiegelt und initialisiert.")

if __name__ == "__main__":
    main()