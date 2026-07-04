import os
import redis
from .auth import AuthError
import os, time, json, redis
from embit.psbt import PSBT

WINDOW_SEC = int(os.getenv("VELOCITY_WINDOW_SEC", "86400"))     # 24h
CAP_SATS   = int(os.getenv("VELOCITY_CAP_SATS", "35000000"))    # Backstop, > Basis-Cap
META_FILE  = os.getenv("WALLET_METADATA", "/psbt-signer/run/wallets/metadata.json")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
MAX_SKEW = int(os.getenv("MAX_SKEW", "30"))

_r = redis.Redis.from_url(REDIS_URL)

def claim_nonce(nonce: str) -> None:
    # SET key value NX EX ttl  -> atomar: nur setzen, wenn noch nicht vorhanden
    ok = _r.set(f"nonce:{nonce}", "1", nx=True, ex=MAX_SKEW * 2)
    if not ok:
        raise AuthError("REPLAY_DETECTED")

class VelocityError(Exception):
    pass

def _master_fp() -> str:
    try:
        with open(META_FILE) as f:
            return json.load(f).get("fingerprint", "").lower()
    except Exception:
        return ""   # fehlt -> alles gilt als Abfluss (konservativ)

def hot_outflow_sats(psbt: PSBT) -> int:
    # Multisig-Input => Cold-Spend => nicht gegen Hot-Limit zählen
    for inp in psbt.inputs:
        if inp.witness_script is not None:
            return 0
    fp = _master_fp()
    outflow = 0
    for i, vout in enumerate(psbt.tx.vout):
        derivs = psbt.outputs[i].bip32_derivations if i < len(psbt.outputs) else {}
        is_change = bool(fp) and any(d.fingerprint.hex().lower() == fp for d in derivs.values())
        if not is_change:
            outflow += vout.value
    return outflow

def check_and_record(psbt_id: str, amount: int) -> None:
    if amount <= 0:
        return
    now, key, cutoff = time.time(), "velocity:hot", time.time() - WINDOW_SEC
    p = _r.pipeline()
    p.zremrangebyscore(key, "-inf", cutoff)          # altes Fenster raus
    p.zrangebyscore(key, cutoff, "+inf")
    _, members = p.execute()
    ids = [m.decode().split("|", 1) for m in members]
    if any(mid == psbt_id for mid, _ in ids):        # Retry: nicht doppelt zählen
        return
    current = sum(int(a) for _, a in ids)
    if current + amount > CAP_SATS:
        raise VelocityError(f"VELOCITY_CAP: {current}+{amount} > {CAP_SATS}")
    _r.zadd(key, {f"{psbt_id}|{amount}": now})
    _r.expire(key, WINDOW_SEC * 2)