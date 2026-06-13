import sys
import os
import subprocess
from embit import bip39

STATE_DIR = "/var/lib/signer"

def get_mnemonic_from_tpm():
    sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")
    session_ctx = os.path.join(STATE_DIR, "active_session.ctx")

    if not os.path.exists(sealed_ctx):
        print("Error: TPM-Kontext fehlt.", file=sys.stderr)
        sys.exit(1)

    # 1. Aktive Policy-Sitzung im TPM starten
    subprocess.run([
        "tpm2_startauthsession", 
        "--policy-session", 
        "-S", session_ctx
    ], check=True, stdout=subprocess.DEVNULL)

    entropy_bytes = b""

    try:
        #aktuellen PCR 7 Wert in Session laden
        subprocess.run([
            "tpm2_policypcr", 
            "-S", session_ctx, 
            "-l", "sha256:7"
        ], check=True, stdout=subprocess.DEVNULL)


        result = subprocess.run([
            "tpm2_unseal", 
            "-c", sealed_ctx, 
            "-p", f"session:{session_ctx}"
        ], capture_output=True, check=True)
        
        # Rohe 32 Bytes
        entropy_bytes = result.stdout
         
    except subprocess.CalledProcessError as e:
        print(f"Errpr beim TPM-Zugriff (PCR 7 verändert?): {e.stderr.decode()}", file=sys.stderr)
        sys.exit(1)
        
    finally:
        # 4. Session-Kontext IMMER im TPM flashen und Datei löschen
        subprocess.run(["tpm2_flushcontext", session_ctx], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(session_ctx):
            os.remove(session_ctx)


    if len(entropy_bytes) == 32:
        mnemonic_phrase = bip39.mnemonic_from_bytes(entropy_bytes)
        return mnemonic_phrase
    else:
        print("Error: entsiegelten Daten nicht 32 Bytes lang", file=sys.stderr)
        sys.exit(1)
