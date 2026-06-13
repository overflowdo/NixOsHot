#!/usr/bin/env python3

from fastapi import FastAPI, Request, HTTPException

from .auth import verify_request, AuthError
from psbt import (
    decode_psbt,
    encode_psbt,
    finalize_psbt,
    extract_rawtx,
    PSBTError
)
from .engine import sign_psbt
import hashlib

app = FastAPI()

SIGNING_SECRET = open("/var/lib/signer/hmac.secret").read().strip()


@app.post("/sign")
async def sign(request: Request):
    body = await request.body()

    ts = request.headers.get("X-Timestamp")
    nonce = request.headers.get("X-Nonce")
    sig = request.headers.get("X-Signature")


    #Verify HMAC key
    try:
        verify_request(SIGNING_SECRET, body, ts, nonce, sig)
    except AuthError as e:
        raise HTTPException(401, str(e))


    #extract data
    data = await request.json()

    response = {
        "intent_id": data.get("intent_id")
    }
    psbt_b64 = data.get("psbt_base64")

    if not psbt_b64:
        raise HTTPException(400, "missing psbt_base64")
    

    #Decode
    try:
        psbt_bytes = decode_psbt(psbt_b64)
    except PSBTError as e:
        raise HTTPException(400, str(e))


    #Sign
    try:
        signed = sign_psbt(psbt_bytes)
    except Exception as e:
        raise HTTPException(500, str(e))
    

    #Hot-Tx worfflow
    if data.get("type") == "hot-tx":
        # FINALIZE PSBT
        try:
            #extract directly
            raw_tx = extract_rawtx(psbt)

        except PSBTError:
            # fallback: finalize then extract
            try:
                psbt = finalize_psbt(psbt)
                raw_tx = extract_rawtx(psbt)
            except Exception as e:
                raise HTTPException(500, f"FINALIZE_OR_EXTRACT_FAILED: {e}")
        
        response.update({
            "psbt_type": "rawtx",
            "rawtx_hex": raw_tx,
            "sha256": hashlib.sha256(bytes.fromhex(raw_tx)).hexdigest()
        })
    
    #Refill workflow
    else:
        #refill = 2-of-3 / not finalizable here
        try:
            response.update({
                "psbt_type": "psbt",
                "signed_psbt_base64": encode_psbt(psbt),
                "sha256": hashlib.sha256(psbt.serialize()).hexdigest()
            })
        except PSBTError as e:
            raise HTTPException(500, str(e))


    return response