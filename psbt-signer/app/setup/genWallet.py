import sys
import os
import json
from hashlib import sha256, new
import subprocess
from bip_utils import (
    Bip84,
    Bip84Coins,
    Bip44Changes
)
from embit import bip39
from embit.bip32 import HDKey
from embit.descriptor import Descriptor
from embit.networks import NETWORKS

STATE_DIR = "/var/lib/signer"

def get_mnemonic_from_tpm():
    sealed_ctx = os.path.join(STATE_DIR, "sealed.ctx")
    if not os.path.exists(sealed_ctx):
        print("Fehler: TPM-Kontextdatei existiert nicht. Zuerst initialisieren!", file=sys.stderr)
        sys.exit(1)

    # tpm2_unseal ausführen, um die Phrase in den RAM zu holen
    result = subprocess.run([
        "tpm2_unseal", 
        "-c", sealed_ctx,
        "-p", "pcr:sha256:7"
    ], capture_output=True, check=True)
    
    return result.stdout.decode('utf-8').strip()


def main():
    NETWORK = "regtest"

    mnemonic = "media ride cigar habit this tuna chair island salt bubble famous zebra"
    mnemonic = get_mnemonic_from_tpm()

    derivation_path = "m/84h/0h/0h" 

    seed = bip39.mnemonic_to_seed(mnemonic)
    del mnemonic

    #Angabe testnet zum bilden tpub statt xpub
    network_config = NETWORKS["test"]

    root_key = HDKey.from_seed(seed)

    fingerprint_hex = root_key.fingerprint.hex()

    account_key = root_key.derive(derivation_path)

    #xpub key mit tpub identifier
    xpub_string = account_key.to_public().to_string(version=network_config["xpub"])

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

if __name__ == "__main__":
    main()