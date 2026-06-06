def load_seed(path="/run/btc/seed") -> bytes:

    # Load TPM-unsealed BIP32 seed from RAM only.

    with open(path, "rb") as f:
        seed = f.read().strip()

    
    if not seed:
        raise Exception("EMPTY_TPM_SEED")
    if len(seed) not in (16, 32, 64):
        raise Exception("INVALID_SEED_LENGTH")

    return seed