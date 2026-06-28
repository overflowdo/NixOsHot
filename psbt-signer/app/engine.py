from .psbtPolicy import validate
from .tpm import get_entropy_from_tpm
from embit import bip39
from embit.psbt import PSBT
from embit.bip32 import HDKey
from embit.networks import NETWORKS

def sign_psbt(psbt: PSBT):

    network_config = NETWORKS["test"]

    # 1. POLICY CHECK (SECURITY GATE)
    validate(psbt)

    entropy = get_entropy_from_tpm()
    mnemonic = bip39.mnemonic_from_bytes(entropy)
    seed = bip39.mnemonic_to_seed(mnemonic)

    root = HDKey.from_seed(seed, version=network_config["xprv"])

    root.fingerprint = root.my_fingerprint


    psbt.sign_with(root)

    return psbt