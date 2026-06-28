#!/usr/bin/env python3

import hmac
import hashlib
import time

class AuthError(Exception):
    pass


def verify_request(secret: str, body: bytes, ts: str, nonce: str, sig: str):
    #replay protection (time window)
    now = int(time.time())
    if abs(now - int(ts)) > 30:    #replay schutz: 30 sek
        raise AuthError("STALE_REQUEST")

    #HMAC verification
    msg = ts.encode() + nonce.encode() + body

    expected = hmac.new(
        secret,
        msg,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected, sig):
        raise AuthError("INVALID_SIGNATURE")