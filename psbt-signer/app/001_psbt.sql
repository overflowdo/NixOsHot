BEGIN;

CREATE SCHEMA IF NOT EXISTS btc;

-- -----------------------------
-- ENUMS
-- -----------------------------
DO $$
BEGIN
  
END $$;
-- -----------------------------
-- PSBT requests
-- -----------------------------
CREATE TABLE IF NOT EXISTS btc.psbt (
  psbt_id          TEXT PRIMARY KEY,
  wallet_type         TEXT NOT NULL CHECK (wallet_type IN ('hot', 'cold')),

  sha256 TEXT NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

COMMIT;