import os
from embit import bip39
from embit.psbt import PSBT
from embit.bip32 import HDKey
from embit.networks import NETWORKS

from .psbtPolicy import validate
from .tpm import get_entropy_from_tpm

NETWORK_SYS = os.getenv("NETWORK", "main")

def sign_psbt(psbt: PSBT):

    #Policy Check Form PSBT
    validate(psbt)

    network_config = NETWORKS[NETWORK_SYS]


    entropy = get_entropy_from_tpm()
    mnemonic = bip39.mnemonic_from_bytes(entropy)
    del entropy
    
    seed = bip39.mnemonic_to_seed(mnemonic)
    del mnemonic

    root = HDKey.from_seed(seed, version=network_config["xprv"])
    del seed

    root.fingerprint = root.my_fingerprint

    before = sum(len(inp.partial_sigs) for inp in psbt.inputs)

    psbt.sign_with(root)
    del root

    after = sum(len(inp.partial_sigs) for inp in psbt.inputs)
    if after <= before:
        raise ValueError("Signer hat keine Signatur hinzugefügt (Key passt nicht zur PSBT)")
    
    return psbt