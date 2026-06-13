from .psbt import load_psbt, serialize_psbt
from .sigHash import get_sighash
from .psbtPolicy import PSBTPolicy


def sign_psbt(psbt_bytes: bytes, wallet):
    psbt = load_psbt(psbt_bytes)

    # 1. POLICY CHECK (SECURITY GATE)
    policy = PSBTPolicy(wallet)
    policy.validate(psbt)

    # 2. SIGNING LOOP
    for i, inp in enumerate(psbt.inputs):

        if not wallet.input_belongs_to_me(inp):
            continue

        # 2.1 compute digest (CRITICAL PART)
        digest = get_sighash(psbt, i)

        # 2.2 TPM signing (NO KEYS LEAVING TPM)
        sig = wallet.sign_input_digest(digest)

        # 2.3 attach signature
        psbt.add_signature(i, sig)

    return serialize_psbt(psbt)