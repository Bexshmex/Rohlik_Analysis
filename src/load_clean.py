"""
Load the cleaned Rohlik dataset (parquet) into PostgreSQL as a star schema.

Tables (schema `analytics`, created by sql/01_create_tables.sql):
    dim_calendar  - 1 row = warehouse x day
    dim_product   - 1 row = product in a warehouse
    fact_orders   - 1 row = warehouse x day (total_orders)
    fact_sales    - 1 row = product x warehouse x day

Usage (from the project root):
    1. run sql/01_create_tables.sql
    2. python src/load_clean.py
    3. run sql/03_indexes.sql
"""
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from load import DB_URL, copy_insert  # reuse settings + fast COPY insert

# 1. Settings
PARQUET_PATH = (
    Path(__file__).resolve().parent.parent
    / "data" / "analyzed" / "rohlik_cleaned.parquet"
)
SCHEMA = "analytics"
CHUNK_SIZE = 200_000

CALENDAR_COLS = ["date", "warehouse", "holiday", "holiday_name", "shops_closed"]
PRODUCT_COLS = [
    "unique_id", "product_unique_id", "name",
    "l1_category_name_en", "l2_category_name_en",
    "l3_category_name_en", "l4_category_name_en",
    "warehouse",
]
SALES_COLS = [
    "unique_id", "date", "warehouse",
    "sales", "sell_price_main", "max_discount", "is_discount",
    "availability", "actual_price_czk",
    "real_revenue_czk", "lost_revenue_czk", "potential_revenue_czk",
]


# 2. Read + basic preparation
def read_clean_data() -> pd.DataFrame:
    print(f"Reading {PARQUET_PATH.name} ...")
    df = pd.read_parquet(PARQUET_PATH)
    df.columns = df.columns.str.strip().str.lower()   # match SQL column names
    df["date"] = pd.to_datetime(df["date"]).dt.date    # DATE without time part

    for col in ["holiday", "shops_closed", "is_discount"]:
        df[col] = df[col].astype(bool)

    print(f"  {len(df):,} rows, {df.shape[1]} columns")
    return df


# 3. Split the flat table into star-schema tables
def build_tables(df: pd.DataFrame) -> dict[str, pd.DataFrame]:
    dim_calendar = df[CALENDAR_COLS].drop_duplicates()

    dim_product = df[PRODUCT_COLS].drop_duplicates()

    # total_orders can have several values per warehouse x day
    # (found in 01_data_quality) -> take the most frequent one
    fact_orders = (
        df.groupby(["date", "warehouse"], as_index=False)["total_orders"]
        .agg(lambda s: s.mode().iloc[0])
    )
    fact_orders["total_orders"] = fact_orders["total_orders"].round().astype(int)

    fact_sales = df[SALES_COLS]

    # order matters because of foreign keys
    return {
        "dim_calendar": dim_calendar,
        "dim_product": dim_product,
        "fact_orders": fact_orders,
        "fact_sales": fact_sales,
    }


# 4. Checks before loading (fail fast with a clear message)
def validate(tables: dict[str, pd.DataFrame]) -> None:
    keys = {
        "dim_calendar": ["date", "warehouse"],
        "dim_product": ["unique_id"],
        "fact_orders": ["date", "warehouse"],
        "fact_sales": ["unique_id", "date"],
    }
    for name, key in keys.items():
        dups = tables[name].duplicated(key).sum()
        if dups:
            raise SystemExit(f"{name}: {dups:,} duplicate keys on {key}. Fix before loading.")

    sales = tables["fact_sales"]
    numeric = sales.select_dtypes("number")
    n_nan = numeric.isna().sum().sum()
    n_inf = np.isinf(numeric).sum().sum()
    if n_nan or n_inf:
        raise SystemExit(
            f"fact_sales: {n_nan:,} NaN and {n_inf:,} inf values "
            f"(check lost_revenue_czk where availability = 0)."
        )

    print("Checks passed: keys unique, no NaN / inf.")


# 5. Load one table
def load_table(engine, name: str, df: pd.DataFrame) -> None:
    print(f"Loading {SCHEMA}.{name} ({len(df):,} rows) ...")
    df.to_sql(
        name,
        engine,
        schema=SCHEMA,
        if_exists="append",   # tables already exist -> keep our DDL (types, keys)
        index=False,
        method=copy_insert,
        chunksize=CHUNK_SIZE,
    )


# 6. Compare database with pandas after loading
def verify(engine, tables: dict[str, pd.DataFrame]) -> None:
    print("\nVerification:")
    with engine.connect() as conn:
        for name, df in tables.items():
            n_db = conn.execute(text(f"SELECT COUNT(*) FROM {SCHEMA}.{name}")).scalar()
            status = "OK" if n_db == len(df) else "MISMATCH"
            print(f"  {name:<13} pandas={len(df):>10,}  db={n_db:>10,}  {status}")

        rev_db = conn.execute(
            text(f"SELECT SUM(real_revenue_czk) FROM {SCHEMA}.fact_sales")
        ).scalar()
    rev_pd = tables["fact_sales"]["real_revenue_czk"].sum()
    diff = abs(float(rev_db) - rev_pd)
    print(f"  revenue       pandas={rev_pd:,.0f}  db={float(rev_db):,.0f}  diff={diff:,.2f}")


# 7. Entry point
def main() -> None:
    df = read_clean_data()
    tables = build_tables(df)
    validate(tables)

    engine = create_engine(DB_URL)

    # clear tables so the script can be re-run safely
    with engine.begin() as conn:
        conn.execute(text(
            f"TRUNCATE {SCHEMA}.fact_sales, {SCHEMA}.fact_orders, "
            f"{SCHEMA}.dim_product, {SCHEMA}.dim_calendar"
        ))

    for name, table in tables.items():
        load_table(engine, name, table)

    verify(engine, tables)
    print("\nDone. Now run sql/03_indexes.sql")


if __name__ == "__main__":
    main()