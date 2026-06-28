#!/usr/bin/env python3

import os
import sys
import subprocess
from embit import bip39

STATE_DIR = "/psbt-signer/tpm"
INIT_MARKER = os.path.join(STATE_DIR, "initialized")


if os.path.exists(INIT_MARKER):
    print("Signer bereits initialisiert.")
    sys.exit(0)

print("1. Mnemonic Phrase (24 Wörter) generieren...")
#Entropy erzeugen
entropy = os.urandom(32)

#In BIP-39 Wörter umwandeln (nur für Ausgabe zum Aufschreiben)
mnemonic_phrase = bip39.mnemonic_from_bytes(entropy)
print(f"Generierte Phrase (wird NICHT TPM gespeichert, spätere Bildung aus Entropie):\n{mnemonic_phrase}")
del mnemonic_phrase

print("TPM Primary Key")
primary_ctx = os.path.join(STATE_DIR, "primary.ctx")
subprocess.run([
    "tpm2_createprimary",
    "-C", "o",
    "-g", "sha256",
    "-G", "ecc", 
    "-c", primary_ctx
], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("versiegeln")
seal_pub = os.path.join(STATE_DIR, "seal.pub")
seal_priv = os.path.join(STATE_DIR, "seal.priv")
sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")

#PCR als Autoriserung nehmen
session_ctx = os.path.join(STATE_DIR, "session.ctx")
policy_file = os.path.join(STATE_DIR, "pcr.policy")

#Starte eine Autorisierungssitzung (Trial Session)
subprocess.run([
    "tpm2_startauthsession",
    "-S", session_ctx
], check=True)

#Berechne die Policy basierend auf dem aktuellen Zustand von PCR 7
subprocess.run([
    "tpm2_policypcr", "-S", session_ctx, "-l", "sha256:7", "-L", policy_file
], check=True)

#Sitzungskontext schließen und aufräumen
subprocess.run(["tpm2_flushcontext", session_ctx], check=True)
if os.path.exists(session_ctx):
    os.remove(session_ctx)

process = subprocess.Popen([
    "tpm2_create", 
    "-C", primary_ctx,
    "-g", "sha256",
    "-u", seal_pub,
    "-r", seal_priv,
    "-L", policy_file,
    "-i", "-",
    "-c", sealed_ctx
], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

#Daten einspeisen und ausführen
_, stderr = process.communicate(input=entropy)

del entropy

if process.returncode != 0:
    print(f"Fehler beim Versiegeln im TPM: {stderr.decode()}", file=sys.stderr)
    sys.exit(1)

with open(INIT_MARKER, "w") as f:
    f.write("1")

print("Entropie im TPM versiegelt und initialisiert.")