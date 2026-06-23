import os
import psycopg
from psycopg.rows import dict_row

DATABASE_URL = os.getenv("DATABASE_URL", "")

def conn():
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL not configured")
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)


#Wenn error auftritt, dass die DB zurückgerollt werden kann
def rollback():
    with conn() as c:
        c.rollback()

#UTXOs

#State logging für psbts (unterscheidung zu intent möglcih, aber unnötig kompliziert)
def insert_psbt(psbt: dict):
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("""
                INSERT INTO btc.psbt (
                    psbt_id,
                    wallet_type,
                    sha256
                )
                VALUES (%s,%s,%s)
            """, (
                psbt.get("psbt_id"),
                psbt.get("wallet_type"),
                psbt.get("sha256")
            ))
        c.commit()