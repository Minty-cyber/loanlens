DB := data/warehouse/loanlens.duckdb

# Run one SQL file read-only against the warehouse and print the result.
# Usage: $(call run_sql,path/to/file.sql)
run_sql = uv run python -c "import duckdb; duckdb.connect('$(DB)', read_only=True).sql(open('$(1)').read()).show(max_rows=100)"

.PHONY: profile build-raw \
        checks check-nulls check-types check-allowed-value check-range check-outlier check-consistency

# --- pipeline -------------------------------------------------------------

profile:
	uv run python pipeline/profile_raw.py

build-raw:
	uv run python pipeline/build_warehouse.py --through 1

# --- data quality checks --------------------------------------------------

checks: check-nulls check-types check-allowed-value check-range check-outlier check-consistency

check-nulls:
	$(call run_sql,sql/checks/null_check.sql)

check-types:
	$(call run_sql,sql/checks/type_check.sql)

check-allowed-value:
	$(call run_sql,sql/checks/allowed_value_check.sql)

check-range:
	$(call run_sql,sql/checks/range_check.sql)

check-outlier:
	$(call run_sql,sql/checks/outlier_check.sql)

check-consistency:
	$(call run_sql,sql/checks/consistency_check.sql)
