from bitcointx.wallet import CBitcoinExtKey
from .tpm import get_mnemonic_from_tpm
import hashlib


class Wallet:
    def __init__(self):
        seed = get_mnemonic_from_tpm()

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