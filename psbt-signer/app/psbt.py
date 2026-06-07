import io
from embit.psbt import PSBT

class PSBTError(Exception):
    pass


def load_psbt(psbt_bytes: bytes) -> PSBT:
    try:
        return PSBT.parse(psbt_bytes)
    except Exception as e:
        raise PSBTError(f"INVALID_PSBT: {e}")


def serialize_psbt(psbt) -> bytes:
    return psbt.serialize()

def finalize_psbt(psbt_bytes: bytes) -> PSBT:
    psbt = PSBT.parse(psbt_bytes)

    psbt.finalize()  # important step

    return psbt

def extract_rawtx(psbt: PSBT) -> str:
    tx = psbt.extract_tx()

    return tx.serialize().hex()