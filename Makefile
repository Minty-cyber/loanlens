DB := data/warehouse/loanlens.duckdb

run_sql = uv run python -c "import duckdb; duckdb.connect('$(DB)', read_only=True).sql(open('$(1)').read()).show(max_rows=100)"

.PHONY: profile build-raw build-staging \
        checks check-nulls check-types check-allowed-value check-range check-outlier check-consistency

profile:
	uv run python pipeline/profile_raw.py

build-raw:
	uv run python pipeline/build_warehouse.py --through 1

build-staging:
	uv run python pipeline/build_warehouse.py --through 2

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

EDA_TARGETS := eda-target-overall eda-target-by-year eda-target-mature-cohort \
               eda-grade eda-sub-grade eda-loan-bands \
               eda-borrower-bands eda-borrower-categories \
               eda-purpose \
               eda-credit-history eda-missingness \
               eda-outlier-flags \
               eda-geography eda-state-spread \
               eda-feature-pairs eda-default-correlation

.PHONY: eda $(EDA_TARGETS)

eda: $(EDA_TARGETS)

eda-target-overall:
	$(call run_sql,sql/eda/01_target_overall.sql)

eda-target-by-year:
	$(call run_sql,sql/eda/01_target_by_year.sql)

eda-target-mature-cohort:
	$(call run_sql,sql/eda/01_target_mature_cohort.sql)

eda-grade:
	$(call run_sql,sql/eda/02_grade.sql)

eda-sub-grade:
	$(call run_sql,sql/eda/02_sub_grade.sql)

eda-loan-bands:
	$(call run_sql,sql/eda/02_loan_bands.sql)

eda-borrower-bands:
	$(call run_sql,sql/eda/03_borrower_bands.sql)

eda-borrower-categories:
	$(call run_sql,sql/eda/03_borrower_categories.sql)

eda-purpose:
	$(call run_sql,sql/eda/04_purpose.sql)

eda-credit-history:
	$(call run_sql,sql/eda/05_credit_history.sql)

eda-missingness:
	$(call run_sql,sql/eda/05_missingness.sql)

eda-outlier-flags:
	$(call run_sql,sql/eda/06_outlier_flags.sql)

eda-geography:
	$(call run_sql,sql/eda/07_geography.sql)

eda-state-spread:
	$(call run_sql,sql/eda/07_state_spread.sql)

eda-feature-pairs:
	$(call run_sql,sql/eda/08_feature_pairs.sql)

eda-default-correlation:
	$(call run_sql,sql/eda/08_default_correlation.sql)
