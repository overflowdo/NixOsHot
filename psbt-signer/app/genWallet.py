import sys
import os
import json
from hashlib import sha256, new
from bip_utils import (
    Bip84,
    Bip84Coins,
    Bip44Changes
)
from embit import bip39
from embit.bip32 import HDKey
from embit.descriptor import Descriptor


# INPUT (from TPM unseal)
seed_hex = sys.stdin.read().strip()
seed_bytes = bytes.fromhex(seed_hex)
del seed_hex
NETWORK = "regtest"

passphrase = ""


# WALLET DERIVATION


mnemonic = "media ride cigar habit this tuna chair island salt bubble famous zebra"
passphrase = ""


derivation_path = "m/84'/0'/0'" 


seed = bip39.mnemonic_to_seed(mnemonic, passphrase=passphrase)


root_key = HDKey.from_seed(seed)


master_fingerprint = root_key.child(0).fingerprint
fingerprint_hex = root_key.fingerprint.hex()


account_key = root_key.derive(derivation_path)


xpub_string = account_key.to_public().to_string()


path_cleaned = derivation_path.replace("m/", "")
descriptor_format = f"wpkh([{fingerprint_hex}/{path_cleaned}]{xpub_string}/0/*)"

# 9. Checksumme berechnen (Sparrow fügt immer eine standardisierte Bitcoin-Core-Checksumme an)
desc_obj = Descriptor.from_string(descriptor_format)
pub_desc = str(desc_obj)

# Ausgabe


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
    f.write(xpub_string)

with open(meta_file, "w") as f:
    json.dump({
        "network": NETWORK,
        "fingerprint": fingerprint_hex,
        "xpub_file": xpub_file,
        "descriptor": pub_desc
    }, f, indent=2)