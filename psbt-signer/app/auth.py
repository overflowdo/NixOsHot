#!/usr/bin/env python3

import hmac
import hashlib
import time
import os

MAX_SKEW = int(os.getenv("MAX_SKEW", "30"))

class AuthError(Exception):
    pass


def verify_request(secret: bytes, body: bytes, ts: str, nonce: str, sig: str):

    if ts is None:
        raise AuthError("missing X-Timestamp")
    if nonce is None:
        raise AuthError("missing X-Nonce")
    if sig is None:
        raise AuthError("missing X-Signature")

    # Empty headers
    if not ts:
        raise AuthError("empty X-Timestamp")
    if not nonce:
        raise AuthError("empty X-Nonce")
    if not sig:
        raise AuthError("empty X-Signature")

    try:
        ts_int = int(ts)
    except (TypeError, ValueError):
        raise AuthError("invalid timestamp")
    
    #replay protection (time window)
    if abs(time.time() - ts_int) > MAX_SKEW:     #replay schutz: 30 sek
        raise AuthError("STALE_REQUEST")

    #HMAC verification
    try:
        msg = (
            str(ts).encode()
            + nonce.encode()
            + body
        )

        expected = hmac.new(
            secret,
            msg,
            hashlib.sha256,
        ).hexdigest()

    except Exception:
        raise AuthError("invalid authentication data")

    try:
        if not hmac.compare_digest(expected, sig):
            raise AuthError("invalid signature")
    except TypeError:
        # compare_digest erwartet gleiche Typen
        raise AuthError("invalid signature")