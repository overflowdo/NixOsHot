class Wallet:
    def __init__(self, tpm, pubkey):
        self.tpm = tpm
        self.pubkey = pubkey

    def sign_digest(self, digest: bytes):
        return self.tpm.sign(digest)

    def get_descriptor(self):
        # simple single-key descriptor
        return f"wpkh({self.pubkey})"