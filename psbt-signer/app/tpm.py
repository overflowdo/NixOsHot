import sys
import os
from hashlib import sha256, new
import subprocess

STATE_DIR = "/var/lib/signer"

def get_mnemonic_from_tpm():
    sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")
    if not os.path.exists(sealed_ctx):
        print("Fehler: TPM-Kontextdatei existiert nicht. Zuerst initialisieren", file=sys.stderr)
        sys.exit(1)

    # tpm2_unseal ausführen -> Phrase in RAM
    result = subprocess.run([
        "tpm2_unseal", 
        "-c", sealed_ctx,
        "-p", "pcr:sha256:7"
    ], capture_output=True, check=True)
    
    return result.stdout.decode('utf-8').strip()