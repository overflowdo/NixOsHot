from bitcointx.core.psbt import PartiallySignedTransaction
import io

class PSBTError(Exception):
    pass


def load_psbt(psbt_bytes: bytes):
    try:
        return PartiallySignedTransaction.deserialize(io.BytesIO(psbt_bytes))
    except Exception as e:
        raise PSBTError(f"INVALID_PSBT: {e}")


def serialize_psbt(psbt) -> bytes:
    buf = io.BytesIO()
    psbt.serialize(buf)
    return buf.getvalue()