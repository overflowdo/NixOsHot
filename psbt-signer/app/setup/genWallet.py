#!/usr/bin/env python3

import os
import json
from embit import bip39
from embit.bip32 import HDKey
from embit.descriptor import Descriptor
from embit.networks import NETWORKS
from binascii import hexlify

from app.tpm import get_entropy_from_tpm

NETWORK_SYS = os.getenv("NETWORK","main")
STATE_DIR = "/psbt-signer/tpm"



entropy = get_entropy_from_tpm()
mnemonic = bip39.mnemonic_from_bytes(entropy)
del entropy

# BIP84 coin_type: 0h = main, 1h = test/regtest/signet
coin = "0h" if NETWORK_SYS == "main" else "1h"
derivation_path = f"m/84h/{coin}/0h"

seed = bip39.mnemonic_to_seed(mnemonic)
del mnemonic

#Angabe testnet zum bilden tpub statt xpub
network_config = NETWORKS[NETWORK_SYS]

root = HDKey.from_seed(seed, version=network_config["xprv"])
del seed

master_fingerprint_hex = hexlify(root.my_fingerprint).decode()

xpub = root.derive(derivation_path).to_public()
del root

# Key-Origin muss exakt dem Ableitungspfad entsprechen:
descriptor_format = f"wpkh([{master_fingerprint_hex}/84h/{coin}/0h]{xpub}/{{0,1}}/*)"


desc_obj = Descriptor.from_string(descriptor_format)
pub_desc = str(desc_obj)

# output Dir
out_dir = os.environ.get("WALLET_OUT_DIR", "/psbt-signer/run/wallets")
os.makedirs(out_dir, exist_ok=True)

pub_file = os.path.join(out_dir, "descriptor.public.txt")
xpub_file = os.path.join(out_dir, "xpub.txt")
meta_file = os.path.join(out_dir, "metadata.json")


#write
with open(pub_file, "w") as f:
    f.write(pub_desc)

with open(xpub_file, "w") as f:
    f.write(str(xpub))

with open(meta_file, "w") as f:
    json.dump({
        "network": NETWORK_SYS,
        "wallet_name": "keyA",
        "wallet_type": "hot",
        "fingerprint": master_fingerprint_hex,
        "xpub_file": xpub_file,
        "descriptor": pub_desc
    }, f, indent=2)