from .psbt import psbt_serialize
from .psbtPolicy import validate
from .tpm import get_entropy_from_tpm
from embit import bip39, bip32
from embit.networks import NETWORKS
from embit.psbt import PSBT

NETWORK = "regtest"

def sign_psbt(psbt: PSBT):

    # 1. POLICY CHECK (SECURITY GATE)
    validate(psbt)

    entropy = get_entropy_from_tpm()

    mnemonic = bip39.mnemonic_from_bytes(entropy)

    seed = bip39.mnemonic_to_seed(mnemonic)

    root = bip32.HDKey.from_seed(
        seed,
        version=NETWORKS[NETWORK]["xprv"]
    )

    signed = 0

    for inp in psbt.inputs:

        if not inp.bip32_derivations:
            continue

        for pubkey, derivation in inp.bip32_derivations.items():

            if derivation.fingerprint != root.my_fingerprint:
                continue

            key = root.derive(
                derivation.derivation
            )

            if inp.sign_with(key):
                signed += 1

    return psbt