from fastapi import FastAPI, Request, HTTPException

from app.auth import verify_request, AuthError
from app.psbt import decode_psbt, encode_psbt, extract_rawtx, finalize_psbt
from app.engine import sign_psbt
import hashlib
from Ttpm2.PyTpm2 import TPMError

app = FastAPI()

SIGNING_SECRET = open("/run/keys/signer_secret").read().strip()


@app.post("/sign")
async def sign(request: Request):
    body = await request.body()

    ts = request.headers.get("X-Timestamp")
    nonce = request.headers.get("X-Nonce")
    sig = request.headers.get("X-Signature")

    try:
        verify_request(SIGNING_SECRET, body, ts, nonce, sig)
    except AuthError as e:
        raise HTTPException(401, str(e))

    data = await request.json()

    psbt_b64 = data["psbt_base64"]

    psbt_bytes = decode_psbt(psbt_b64)
    response = {"intent_id": data.get("intent_id"),}

    try:
        signed = sign_psbt(psbt_bytes)
    except TPMError as e:
        raise HTTPException(503, str(e))
    except Exception as e:
        raise HTTPException(500, str(e))
    
    if data.get("type") == "hot-tx":
        # FINALIZE PSBT
        try:
            finalized = finalize_psbt(signed)
        except Exception as e:
            raise HTTPException(500, f"finalize failed: {e}")

        # EXTRACT RAW TX
        try:
            psbt_out = extract_rawtx(finalized)
            response["psbt_type"] = "rawtx"
            response["rawtx_hex"] = psbt_out
            response["sha256"] = hashlib.sha256(psbt_out.encode()).hexdigest()
        except Exception as e:
            raise HTTPException(500, f"extract tx failed: {e}")
        
    else:
        # refill = 2-of-3 / not finalizable here
        response["signed_psbt_base64"] = encode_psbt(signed)
        response["psbt_type"] = "psbt"


    return response