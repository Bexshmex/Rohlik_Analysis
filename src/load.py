"""
Load every CSV from data/raw/ into PostgreSQL (schema `raw`) as-is.
sales_train.csv -> raw.sales_train, inventory.csv -> raw.inventory, ...

Usage (from the project root):
    python src/load.py
"""
import csv
import io
import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

# 1. Settings
DB_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://rohlik:rohlik@localhost:5432/rohlik",
)
DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
CHUNK_SIZE = 200_000  # read CSVs in chunks to keep memory usage low


# 2. Fast insert via PostgreSQL COPY (much faster than row-by-row INSERT)
def copy_insert(table, conn, keys, data_iter):
    dbapi_conn = conn.connection
    with dbapi_conn.cursor() as cur:
        buf = io.StringIO()
        csv.writer(buf).writerows(data_iter)
        buf.seek(0)
        columns = ", ".join(f'"{k}"' for k in keys)
        cur.copy_expert(
            f"COPY {table.schema}.{table.name} ({columns}) FROM STDIN WITH CSV",
            buf,
        )


# 3. Load a single CSV file into raw.<file_name>
def load_csv(engine, path: Path) -> int:
    table = path.stem.lower()
    total = 0
    for i, chunk in enumerate(pd.read_csv(path, chunksize=CHUNK_SIZE)):
        chunk.columns = [c.strip().lower() for c in chunk.columns]
        if "date" in chunk.columns:
            chunk["date"] = pd.to_datetime(chunk["date"]).dt.date  # store as DATE, no time part

        chunk.to_sql(
            table,
            engine,
            schema="raw",
            if_exists="replace" if i == 0 else "append",  # first chunk recreates the table
            index=False,
            method=copy_insert,
        )
        total += len(chunk)
        print(f"  {table}: {total:,} rows", end="\r")
    print()
    return total


# 4. Entry point
def main() -> None:
    files = sorted(DATA_DIR.glob("*.csv"))
    if not files:
        raise SystemExit(f"No CSV files found in {DATA_DIR}. Download the Kaggle data first.")

    engine = create_engine(DB_URL)
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

    for f in files:
        print(f"Loading {f.name} ...")
        n = load_csv(engine, f)
        print(f"  -> raw.{f.stem.lower()}: {n:,} rows")

    print("Done.")


if __name__ == "__main__":
    main()