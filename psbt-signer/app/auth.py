import hmac
import hashlib
import time

class AuthError(Exception):
    pass


def verify_request(secret: str, body: bytes, ts: str, nonce: str, sig: str):
    # 1. replay protection (time window)
    now = int(time.time())
    if abs(now - int(ts)) > 10:
        raise AuthError("STALE_REQUEST")

    # 2. HMAC verification
    msg = ts.encode() + nonce.encode() + body

    expected = hmac.new(
        secret.encode(),
        msg,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected, sig):
        raise AuthError("INVALID_SIGNATURE")