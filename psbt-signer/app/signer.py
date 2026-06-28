#!/usr/bin/env python3

from fastapi import FastAPI, Request, HTTPException
import json
import base64
import logging
from .auth import verify_request, AuthError
from .psbt import (
    decode_psbt,
    encode_psbt,
    psbt_serialize,
    PSBTError
)
from .db import insert_psbt
from .engine import sign_psbt
import hashlib
from psycopg.errors import UniqueViolation

SIGNER_HMAC_SECRET = "/psbt-signer/run/secrets/hmac.secret"
with open(SIGNER_HMAC_SECRET, "r") as f:
    SIGNING_SECRET = bytes.fromhex(f.read().strip())

app = FastAPI()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s"
)
log = logging.getLogger(__name__)


@app.post("/sign")
async def sign(request: Request):
    body = await request.body()

    ts = request.headers.get("X-Timestamp")
    nonce = request.headers.get("X-Nonce")
    sig = request.headers.get("X-Signature")

    log.info(
        "received psbt",
        extra={
            "ts": ts,
            "nonce": nonce,
            "sig": sig,
        }
    )

    #Verify HMAC key
    try:
        verify_request(SIGNING_SECRET, body, ts, nonce, sig)
    except AuthError as e:
        raise HTTPException(401, str(e))


    #extract data
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(400, "Invalid JSON body")

    psbt_b64 = data.get("psbt")

    if not psbt_b64:
        raise HTTPException(400, "missing psbt_base64")
    
    psbt_bytes = base64.b64decode(psbt_b64)

    #sha256 check. gegen manipulationd der psbt
    if hashlib.sha256(psbt_bytes).hexdigest() != data.get("sha256"):
        raise HTTPException(
            status_code=400,
            detail="sha256 mismatch (PSBT tampering detected)"
        )

    try:
        insert_psbt(data)
    except UniqueViolation:
        return {
            "status": "ALREADY_PROCESSED",
            "psbt_id": data.get("psbt_id")
        }

    response = {
        "psbt_id": data.get("psbt_id")
    }
    
    #Decode
    try:
        psbt = decode_psbt(psbt_b64)
    except PSBTError as e:
        raise HTTPException(400, str(e))

    #Sign
    try:
        psbt_signed = sign_psbt(psbt)
    except Exception as e:
        raise HTTPException(500, str(e))
    
    try:
        response.update({
            "wallet_type": data.get("wallet_type"),
            "psbt": encode_psbt(psbt_signed),
            "sha256": hashlib.sha256(psbt_serialize(psbt_signed)).hexdigest()
        })
    except PSBTError as e:
        raise HTTPException(500, str(e))


    return response