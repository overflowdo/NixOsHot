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

# BIP84 -> Single-Sig, nativ SegWit   (Hot)
# BIP48 -> Multisig-Cosigner, Script-Typ 2 = P2WSH   (Cold)
derivation_path_singlesig = f"m/84h/{coin}/0h"
derivation_path_multisig  = f"m/48h/{coin}/0h/2h"

seed = bip39.mnemonic_to_seed(mnemonic)
del mnemonic

#Angabe testnet zum bilden tpub statt xpub
network_config = NETWORKS[NETWORK_SYS]

root = HDKey.from_seed(seed, version=network_config["xprv"])
del seed

master_fingerprint_hex = hexlify(root.my_fingerprint).decode()

xpub_singlesig = root.derive(derivation_path_singlesig).to_public()
xpub_multisig  = root.derive(derivation_path_multisig).to_public()
del root

# Key-Origin muss exakt dem Ableitungspfad entsprechen:
descriptor_singlesig = f"wpkh([{master_fingerprint_hex}/84h/{coin}/0h]{xpub_singlesig}/{{0,1}}/*)"
desc_obj = Descriptor.from_string(descriptor_singlesig)
pub_desc_singlesig = str(desc_obj)


cosigner_multisig = f"[{master_fingerprint_hex}/48h/{coin}/0h/2h]{xpub_multisig}/<0;1>/*"

# output Dir für 84h
out_dir = os.environ.get("WALLET_OUT_DIR", "/psbt-signer/run/wallets")
os.makedirs(out_dir, exist_ok=True)

pub_file = os.path.join(out_dir, "descriptor.public.txt")
xpub_file = os.path.join(out_dir, "xpub.txt")
meta_file = os.path.join(out_dir, "metadata.json")

#write
with open(pub_file, "w") as f:
    f.write(pub_desc_singlesig)

with open(xpub_file, "w") as f:
    f.write(str(xpub_singlesig))

with open(meta_file, "w") as f:
    json.dump({
        "network": NETWORK_SYS,
        "wallet_name": "keyA",
        "wallet_type": "hot",
        "fingerprint": master_fingerprint_hex,
        "xpub_file": xpub_file,
        "descriptor": pub_desc_singlesig
    }, f, indent=2)


#fuer multi sig 48
pub_file_ms  = os.path.join(out_dir, "descriptor.multisig.txt")
xpub_file_ms = os.path.join(out_dir, "xpub.multisig.txt")
meta_file_ms = os.path.join(out_dir, "metadata.multisig.json")

with open(pub_file_ms, "w") as f:
    f.write(cosigner_multisig)

with open(xpub_file_ms, "w") as f:
    f.write(str(xpub_multisig))

with open(meta_file_ms, "w") as f:
    json.dump({
        "network": NETWORK_SYS,
        "wallet_name": "keyA",
        "wallet_type": "cold",
        "master_fingerprint": master_fingerprint_hex,
        "derivation_path": f"48h/{coin}/0h/2h",
        "xpub_file": xpub_file_ms,
        "xpub": str(xpub_multisig),
        "descriptor": cosigner_multisig
    }, f, indent=2)