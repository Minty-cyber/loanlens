"""Quick profile of the raw data"""
import duckdb
from config import DOCS_DIR, RAW_CSV


def main() -> None:
    if not RAW_CSV.exists():
        raise SystemExit(
            f"Raw file not found: {RAW_CSV}"
        )
    con = duckdb.connect()
    src = f"read_csv('{RAW_CSV.as_posix()}', header=true, sample_size=-1)"
    lines = ["# Raw data profile", ""]
    
    rows = con.execute(
        f"select count(*) from {src}"
    ).fetchone()[0]
    lines += [f"Rows: {rows:,}", "", "## Columns", "", "| column | type | null % |", "|---|---|---|"]
    cols = con.execute(f"DESCRIBE SELECT * FROM {src}").fetchall()
    for name, dtype, *_ in cols:
        nulls = con.execute(f'SELECT avg(("{name}" IS NULL)::INT) FROM {src}').fetchone()[0]
        lines.append(f"| {name} | {dtype} | {nulls * 100:.1f} |")

    lines += ["", "## loan_status", "", "| value | rows |", "|---|---|"]
    for value, n in con.execute(
        f"SELECT loan_status, count(*) FROM {src} GROUP BY 1 ORDER BY 2 DESC"
    ).fetchall():
        lines.append(f"| {value} | {n:,} |")

    lines += ["", "## Loans per issue year", "", "| year | rows |", "|---|---|"]
    for year, n in con.execute(
        f"""SELECT year(CAST(strptime(issue_d, '%b-%Y') AS DATE)) AS y, count(*)
            FROM {src} GROUP BY 1 ORDER BY 1"""
    ).fetchall():
        lines.append(f"| {year} | {n:,} |")

    out = DOCS_DIR / "raw_profile.md"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"\nSaved to {out}")
    
    
if __name__ == "__main__":
    main()