import os
from embit import bip39
from embit.psbt import PSBT
from embit.bip32 import HDKey
from embit.networks import NETWORKS

from .psbtPolicy import validate
from .tpm import get_entropy_from_tpm

NETWORK_SYS = os.getenv("NETWORK", "mainnet")

def sign_psbt(psbt: PSBT):

    network_config = NETWORKS[NETWORK_SYS]

    #Policy Check Form PSBT
    validate(psbt)

    entropy = get_entropy_from_tpm()
    mnemonic = bip39.mnemonic_from_bytes(entropy)
    del entropy
    
    seed = bip39.mnemonic_to_seed(mnemonic)
    del mnemonic

    root = HDKey.from_seed(seed, version=network_config["xprv"])
    del seed

    root.fingerprint = root.my_fingerprint

    psbt.sign_with(root)
    del root

    return psbt