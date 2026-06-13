class PSBTPolicyError(Exception):
    pass


class PSBTPolicy:

    def __init__(self, wallet):
        self.wallet = wallet

    def validate(self, psbt):
        self._check_inputs(psbt)
        self._check_outputs(psbt)
        self._check_structure(psbt)

    def _check_inputs(self, psbt):
        for i, inp in enumerate(psbt.inputs):

            if inp.witness_utxo is None:
                raise PSBTPolicyError("SegWit requires witness_utxo")
            
            if not inp.witness_utxo.script_pubkey.startswith(b"\x00"):
                raise PSBTPolicyError("not native segwit")

            if not self.wallet.input_belongs_to_me(inp):
                continue

            if not inp.bip32_derivation:
                raise PSBTPolicyError(f"INPUT {i}: missing derivation path")

    def _check_outputs(self, psbt):
        total_out = 0

        for out in psbt.tx.vout:

            # basic sanity check (extend later!)
            if out.value <= 0:
                raise PSBTPolicyError("invalid output value")

            total_out += out.value

        if total_out == 0:
            raise PSBTPolicyError("invalid transaction: zero output value")

    def _check_structure(self, psbt):
        if len(psbt.inputs) == 0:
            raise PSBTPolicyError("no inputs in PSBT")

        if psbt.tx is None:
            raise PSBTPolicyError("missing base transaction")