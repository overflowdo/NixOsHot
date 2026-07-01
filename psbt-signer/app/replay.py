import os
import redis
from .auth import AuthError

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
MAX_SKEW = int(os.getenv("MAX_SKEW", "30"))

_r = redis.Redis.from_url(REDIS_URL)

def claim_nonce(nonce: str) -> None:
    # SET key value NX EX ttl  -> atomar: nur setzen, wenn noch nicht vorhanden
    ok = _r.set(f"nonce:{nonce}", "1", nx=True, ex=MAX_SKEW * 2)
    if not ok:
        raise AuthError("REPLAY_DETECTED")