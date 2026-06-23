from .psbtPolicy import validate
from .tpm import get_entropy_from_tpm
from embit import bip39
from embit.psbt import PSBT
from embit.bip32 import HDKey

def sign_psbt(psbt: PSBT):

    # 1. POLICY CHECK (SECURITY GATE)
    validate(psbt)

    entropy = get_entropy_from_tpm()
    mnemonic = bip39.mnemonic_from_bytes(entropy)
    seed = bip39.mnemonic_to_seed(mnemonic)

    root = HDKey.from_seed(seed)

    fingerprint = root.fingerprint

    #Kontrolle, dass die psbt zum keymaterial gehört
    for inp in psbt.inputs:
        if not inp.bip32_derivations:
            continue
        for derivation in inp.bip32_derivations.items():

            if derivation.fingerprint != fingerprint:
                return psbt

    psbt.sign_with(root)

    return psbt