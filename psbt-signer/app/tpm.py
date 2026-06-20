#!/usr/bin/env python3

import sys
import os
import subprocess


STATE_DIR = "/psbt-signer/tpm"

def get_entropy_from_tpm():
    sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")
    session_ctx = os.path.join(STATE_DIR, "active_session.ctx")

    if not os.path.exists(sealed_ctx):
        print("Error: TPM-Kontext fehlt.", file=sys.stderr)
        sys.exit(1)


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
        #Session-Kontext IMMER TPM flashen und Datei löschen
        subprocess.run(["tpm2_flushcontext", session_ctx], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(session_ctx):
            os.remove(session_ctx)


    if len(entropy_bytes) == 32:
        return entropy_bytes
    else:
        print("Error: entsiegelten Daten nicht 32 Bytes lang", file=sys.stderr)
        sys.exit(1)
