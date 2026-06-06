from app.psbt import load_psbt, serialize_psbt
from app.wallet import Wallet

def sign_psbt(psbt_bytes: bytes):
    psbt = load_psbt(psbt_bytes)

    wallet = Wallet()

    my_fingerprint = wallet.fingerprint()

    for index, inp in enumerate(psbt.inputs):

        if not wallet.input_belongs_to_me(inp):
            continue

        key = wallet.derive_for_input(inp)

        psbt.sign_input(index, key)

    return serialize_psbt(psbt)