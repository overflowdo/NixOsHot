import sys
import os
from hashlib import sha256, new
import subprocess

STATE_DIR = "/var/lib/signer"

def get_mnemonic_from_tpm():
    
    sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")
    session_ctx = os.path.join(STATE_DIR, "active_session.ctx")
    policy_file = os.path.join(STATE_DIR, "pcr.policy")

    if not os.path.exists(sealed_ctx) or not os.path.exists(policy_file):
        print("Fehler: TPM-Kontext oder Policy fehlt. Zuerst initialisieren!", file=sys.stderr)
        sys.exit(1)

    # Aktive Policy-Sitzung starten
    subprocess.run([
        "tpm2_startauthsession", 
        "--policy-session", 
        "-S", session_ctx
    ], check=True)

    try:
        #aktuellen PCR-Wert in die Sitzung laden.
        # PCR 7 Fehlschlagen bei Änderung
        subprocess.run([
            "tpm2_policypcr", 
            "-S", session_ctx, 
            "-l", "sha256:7", 
            "-L", policy_file
        ], check=True)

        # 3. Unseal ausführen und die verifizierte Session übergeben
        # Syntax: "-p session:Pfade_zur_sitzung" autorisiert das Objekt
        result = subprocess.run([
            "tpm2_unseal", 
            "-c", sealed_ctx, 
            "-p", f"session:{session_ctx}"
        ], capture_output=True, check=True)
        
        return result.stdout.decode('utf-8').strip()
         

    finally:
        # 4. Session-Kontext unter allen Umständen im TPM-Chip schließen und Datei löschen
        result = subprocess.run(["tpm2_flushcontext", session_ctx], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if os.path.exists(session_ctx):
            os.remove(session_ctx)