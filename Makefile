DB := data/warehouse/loanlens.duckdb

# Run one SQL file read-only against the warehouse and print the result.
# Usage: $(call run_sql,path/to/file.sql)
run_sql = uv run python -c "import duckdb; duckdb.connect('$(DB)', read_only=True).sql(open('$(1)').read()).show(max_rows=100)"

.PHONY: profile build-raw

# --- pipeline -------------------------------------------------------------

profile:
	uv run python pipeline/profile_raw.py

build-raw:
	uv run python pipeline/build_warehouse.py --through 1
