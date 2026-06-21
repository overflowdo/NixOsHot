#!/usr/bin/env python3

import os
import json
from embit import bip39
from embit.bip32 import HDKey
from embit.descriptor import Descriptor
from embit.networks import NETWORKS
import sys


STATE_DIR = "/psbt-signer/tpm"

# Errechnet den Pfad zu 'scripts/' (ein Ordner über 'setup/')
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PARENT_DIR = os.path.dirname(SCRIPT_DIR)
sys.path.append(PARENT_DIR)

from tpm import get_entropy_from_tpm

NETWORK = "test"


entropy = get_entropy_from_tpm()
mnemonic = bip39.mnemonic_from_bytes(entropy)
del entropy

derivation_path = "m/84h/1h/0h"    #1 für testnet, 0 für mainnet

seed = bip39.mnemonic_to_seed(mnemonic)
del mnemonic

#Angabe testnet zum bilden tpub statt xpub
network_config = NETWORKS[NETWORK]

root = HDKey.from_seed(seed)
del seed

fingerprint_hex = root.fingerprint.hex()


account_key = root.derive(derivation_path)
del root

#xpub key mit tpub identifier
xpub_string = account_key.to_public().to_string(version=network_config["xpub"])
del account_key

path_cleaned = derivation_path.replace("m/", "")
descriptor_format = f"wpkh([{fingerprint_hex}/{path_cleaned}]{xpub_string}/0/*)"


desc_obj = Descriptor.from_string(descriptor_format)
pub_desc = str(desc_obj)


# output Dir
out_dir = os.environ.get("STATE_DIR", "/psbt-signer/run/wallets")
os.makedirs(out_dir, exist_ok=True)

pub_file = os.path.join(out_dir, "descriptor.public.txt")
xpub_file = os.path.join(out_dir, "xpub.txt")
meta_file = os.path.join(out_dir, "metadata.json")


#write
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