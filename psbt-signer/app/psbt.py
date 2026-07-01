#!/usr/bin/env python3

from embit.psbt import PSBT
import base64

class PSBTError(Exception):
    pass


def encode_psbt(psbt: PSBT) -> str:
    try:
        return base64.b64encode(psbt.serialize()).decode()
    except Exception as e:
        raise PSBTError(f"ENCODE_FAILED: {e}")

def decode_psbt(psbt_b64: str) -> PSBT:
    try:
        raw = base64.b64decode(psbt_b64)
        return PSBT.parse(raw)
    except Exception as e:
        raise PSBTError(f"DECODE_FAILED: {e}")
    
def psbt_serialize(psbt: PSBT) -> bytes:
    return psbt.serialize()