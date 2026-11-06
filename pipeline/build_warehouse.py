import argparse
import re
import time

import duckdb
from config import DB_PATH, RAW_CSV, SQL_DIR, SQL_FILES

RAW_CSV_PLACEHOLDER = re.compile(r"\{\{\s*RAW_CSV\s*\}\}")


def build(through: int = len(SQL_FILES)) -> None:
    if not RAW_CSV.exists():
        raise SystemExit(
            f"Raw file not found: {RAW_CSV}\n"
            "Put lending_club_loan_two.csv in data/raw/ and run again."
        )
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH))
    for name in SQL_FILES[:through]:
        sql = (SQL_DIR / name).read_text(encoding="utf-8")
        sql = RAW_CSV_PLACEHOLDER.sub(RAW_CSV.as_posix(), sql)
        start = time.time()
        con.execute(sql)
        print(f"  ran {name} in {time.time() - start:.1f}s")

    print("\nRow counts:")
    for table in ["raw.loans", "stg.valid_loans", "stg.rejected_loans", "mart.fact_loans"]:
        schema, name = table.split(".")
        exists = con.execute(
            "SELECT count(*) FROM information_schema.tables WHERE table_schema = ? AND table_name = ?",
            [schema, name],
        ).fetchone()[0]
        if exists:
            n = con.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
            print(f"  {table:<20} {n:>10,}")
    con.close()
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--through", type=int, default=len(SQL_FILES),
        help="run SQL files 1..N (1 = raw only)",
    )
    build(parser.parse_args().through)