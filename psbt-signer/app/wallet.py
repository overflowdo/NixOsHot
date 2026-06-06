from bitcointx.wallet import CBitcoinSecret, CBitcoinExtKey
from bitcointx.core.psbt import PartiallySignedTransaction
from app.tpm import load_seed
import hashlib


class Wallet:
    def __init__(self):
        seed = load_seed()

        # BIP32 root from seed
        self.root = CBitcoinExtKey.from_seed(seed)

    def derive_key(self, path: str):

        key = self.root

        for level in path.split("/")[1:]:
            hardened = level.endswith("'")
            index = int(level.replace("'", ""))

            if hardened:
                index += 0x80000000

            key = key.ChildKey(index)

        return key

    def sign_input(self, psbt, input_index: int, privkey):
        psbt.sign_input(input_index, privkey)