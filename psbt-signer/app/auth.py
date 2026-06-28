#!/usr/bin/env python3

import hmac
import hashlib
import time
import os

MAX_SKEW = os.getenv("MAX_SKEW", 30)

class AuthError(Exception):
    pass


def verify_request(secret: str, body: bytes, ts: str, nonce: str, sig: str):

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
        ts = int(ts)
    except (TypeError, ValueError):
        raise AuthError("invalid timestamp")
    
    if abs(time.time() - ts) > MAX_SKEW:
        raise AuthError("timestamp expired")


    #replay protection (time window)
    now = int(time.time())
    if abs(now - int(ts)) > 30:    #replay schutz: 30 sek
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


    expected = hmac.new(
        secret,
        msg,
        hashlib.sha256
    ).hexdigest()

    try:
        if not hmac.compare_digest(expected, sig):
            raise AuthError("invalid signature")
    except TypeError:
        # compare_digest erwartet gleiche Typen
        raise AuthError("invalid signature")