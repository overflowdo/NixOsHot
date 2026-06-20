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
  psbt_type         TEXT NOT NULL CHECK (psbt_type IN ('hot-tx', 'refill')),

  sha256 TEXT NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

COMMIT;