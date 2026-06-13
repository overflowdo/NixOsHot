class PSBTPolicyError(Exception):
    pass


def check_structure(psbt):
    if psbt.tx is None:
        raise PSBTPolicyError(
            "missing transaction"
        )

    if len(psbt.inputs) == 0:
        raise PSBTPolicyError(
            "no inputs"
        )


def check_inputs(psbt):
    for i, inp in enumerate(psbt.inputs):
        if inp.witness_utxo is None:
            raise PSBTPolicyError(
                f"INPUT {i}: missing witness_utxo"
            )
        
        if not inp.bip32_derivations:
            raise PSBTPolicyError(
                f"INPUT {i}: missing derivation"
            )


def check_outputs(psbt):
    for i, out in enumerate(psbt.tx.vout):
        if out.value <= 0:
            raise PSBTPolicyError(
                f"OUTPUT {i}: invalid value"
            )


def validate(psbt):
    check_structure(psbt)
    check_inputs(psbt)
    check_outputs(psbt)