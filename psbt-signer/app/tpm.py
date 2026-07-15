#!/usr/bin/env python3

import sys
import os
import subprocess

STATE_DIR = "/psbt-signer/tpm"
PERSISTENT_HANDLE = "0x81010001"


def get_entropy_from_tpm():
    session_ctx = os.path.join(STATE_DIR, "active_session.ctx")
    entropy_bytes = b""
    session_started = False

    try:
        subprocess.run([
            "tpm2_startauthsession", 
            "--policy-session", 
            "-S", session_ctx
        ], check=True, stdout=subprocess.DEVNULL)

        session_started = True

        #aktuellen PCR Wert in Session laden
        subprocess.run([
            "tpm2_policypcr", 
            "-S", session_ctx, 
            "-l", "sha256:4,9,12"
        ], check=True, stdout=subprocess.DEVNULL)


        result = subprocess.run([
            "tpm2_unseal", 
            "-c", PERSISTENT_HANDLE, 
            "-p", f"session:{session_ctx}"
        ], capture_output=True, check=True)
        
        # Rohe 32 Bytes
        entropy_bytes = result.stdout

    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"TPM-Zugriff fehlgeschlagen (PCR 4,8,9,11 verändert?): {e.stderr.decode()}")
        
    finally:
        #Session-Kontext IMMER TPM flashen und Datei löschen
        if session_started:
            subprocess.run(["tpm2_flushcontext", session_ctx],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(session_ctx):
            os.remove(session_ctx)


    if len(entropy_bytes) == 32:
        return entropy_bytes
    else:
        raise RuntimeError("Error: entsiegelten Daten nicht 32 Bytes lang")
