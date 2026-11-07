import duckdb

from config import DB_PATH, EXPORT_DIR, MART_TABLES

def export() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH), read_only=True)
    for table in MART_TABLES:
        parquet = (EXPORT_DIR / f"{table}.parquet").as_posix()
        csv = (EXPORT_DIR / f"{table}.csv").as_posix()
        con.execute(f"copy (select * from mart.{table}) to '{parquet}' (format parquet)")
        con.execute(f"copy (select * from mart.{table}) to '{csv}' (format csv, header)")
        n = con.execute(f"select count(*) from mart.{table}").fetchone()[0]
        print(f"  exported {table:<20} {n:>10,} rows")
    con.close()
    
    
if __name__ == "__main__":
    export()
