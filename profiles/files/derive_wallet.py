import sys
import os
import json
from bip_utils import (
    Bip84,
    Bip84Coins,
    Bip44Changes
)


# INPUT (from TPM unseal)
seed_hex = sys.stdin.read().strip()
seed_bytes = bytes.fromhex(seed_hex)
del seed_hex
NETWORK = "regtest"

passphrase = ""


# WALLET DERIVATION
bip84_ctx = Bip84.FromSeed(seed_bytes, Bip84Coins.BITCOIN)

del seed_bytes

account = bip84_ctx.Purpose().Coin().Account(0)
change = account.Change(Bip44Changes.CHAIN_EXT)

fingerprint = bip84_ctx.PrivateKey().PublicKey().Fingerprint().ToHex()

xpub = account.PublicKey().ToExtended()


pub_desc = f"wpkh([{fingerprint}/84h/0h/0h]{xpub}/0/*)"
change_desc   = f"wpkh([{fingerprint}/84h/0h/0h]{xpub}/1/*)"



# OUTPUT DIRS
out_dir = os.environ.get("STATE_DIR", "/var/lib/signer/wallet")
os.makedirs(out_dir, exist_ok=True)

pub_file = os.path.join(out_dir, "descriptor.public.txt")
xpub_file = os.path.join(out_dir, "xpub.txt")
meta_file = os.path.join(out_dir, "metadata.json")


# WRITE PUBLIC DATA
with open(pub_file, "w") as f:
    f.write(pub_desc)

with open(xpub_file, "w") as f:
    f.write(xpub)

with open(meta_file, "w") as f:
    json.dump({
        "network": NETWORK,
        "fingerprint": fingerprint,
        "xpub_file": xpub_file,
        "descriptor": pub_desc,
        "change_descriptor": change_desc
    }, f, indent=2)