import os
import psycopg
from psycopg.rows import dict_row

DB_HOST = os.getenv("POSTGRES_HOST", "postgres")
DB_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
DB_USER = os.getenv("POSTGRES_USER", "")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "")
DB_NAME = os.getenv("POSTGRES_DB", "")

def conn():
    if not DB_USER or not DB_NAME:
        raise RuntimeError("Postgres credentials not configured")
    return psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        dbname=DB_NAME,
        row_factory=dict_row,
    )


#Wenn error auftritt, dass die DB zurückgerollt werden kann
def rollback():
    with conn() as c:
        c.rollback()


#State logging für psbts
def insert_psbt(psbt: dict):
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("""
                INSERT INTO btc.psbt (
                    psbt_id,
                    sha256
                )
                VALUES (%s,%s)
            """, (
                psbt.get("psbt_id"),
                psbt.get("sha256")
            ))
        c.commit()