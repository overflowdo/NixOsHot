from embit.transaction import Transaction


def get_sighash(psbt, input_index: int) -> bytes:
    #Native SegWit (P2WPKH) BIP143 sighash

    try:
        tx = psbt.tx
        inp = psbt.inputs[input_index]

        utxo = inp.witness_utxo
        if utxo is None:
            raise Exception("missing witness_utxo")

        digest = tx.get_sighash(
            input_index,
            value=utxo.value,
            script=utxo.script_pubkey
        )

        return digest

    except Exception as e:
        raise Exception(f"BIP143_SIGHASH_FAILED: {e}")