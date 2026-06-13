#!/usr/bin/env python3
import subprocess


class TPM:
    def __init__(self):
        self.key_handle = 0x81010002  # persistent TPM key

    def sign(self, digest: bytes) -> bytes:
        try:
            result = subprocess.run([
                "tpm2_sign",
                "-c", str(self.key_handle),
                "-g", "sha256",
                "-d", digest.hex()
            ], capture_output=True, check=True)

            return result.stdout

        except subprocess.CalledProcessError as e:
            raise Exception(f"TPM_SIGN_FAILED: {e.stderr.decode()}")
