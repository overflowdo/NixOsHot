BEGIN;

CREATE SCHEMA IF NOT EXISTS btc;
-- -----------------------------
-- PSBT requests
-- -----------------------------
CREATE TABLE IF NOT EXISTS btc.psbt (
  psbt_id       TEXT PRIMARY KEY,

  sha256        TEXT NOT NULL,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()

);

COMMIT;