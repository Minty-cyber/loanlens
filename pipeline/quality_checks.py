import sys
import duckdb

from config import DB_PATH

CHECKS = [
    ("row_conservation", "FAIL",
     """select abs((select count(*) from raw.loans)
                 - (select count(*) from mart.fact_loans)
                 - (select count(*) from stg.rejected_loans))""",
     "raw rows = fact rows + rejected rows"),
    ("loan_id_unique", "FAIL",
     "select count(*) - count(distinct loan_id) from mart.fact_loans",
     "one fact row per loan"),
    ("no_null_foreign_keys", "FAIL",
     """select count(*) from mart.fact_loans
        where date_key is null or grade_key is null or purpose_key is null or term_key is null
           or home_ownership_key is null or verification_status_key is null
           or dti_band_key is null or income_band_key is null""",
     "every fact row joins to every dimension"),
    ("loan_amount_positive", "FAIL",
     "select count(*) from mart.fact_loans where requested_amount is null or requested_amount <= 0",
     "requested amounts are present and positive"),
    ("interest_rate_in_range", "FAIL",
     "select count(*) from mart.fact_loans where interest_rate_pct is null or interest_rate_pct < 0 or interest_rate_pct > 40",
     "interest rate between 0 and 40 percent"),
    ("status_values_known", "FAIL",
     "select count(*) from mart.fact_loans where loan_status not in ('Fully Paid', 'Charged Off') or loan_status is null",
     "only Fully Paid and Charged Off reach the fact table (others are rejected in staging)"),
    ("default_flag_binary", "FAIL",
     "select count(*) from mart.fact_loans where default_flag not in (0, 1) or default_flag is null",
     "default flag is 0 or 1"),
    ("grades_valid", "FAIL",
     "select count(*) from mart.dim_grade where credit_grade not in ('A','B','C','D','E','F','G')",
     "grades are A to G"),
    ("rejected_rows", "WARN",
     "select count(*) from stg.rejected_loans",
     "rows rejected in staging (see stg.rejected_loans)"),
    ("dti_outliers", "WARN",
     "select count(*) filter (where is_dti_outlier) from mart.fact_loans",
     "debt-to-income above 100 (the 9999 placeholder is set to NULL), flagged"),
    ("income_outliers", "WARN",
     "select count(*) filter (where is_income_outlier) from mart.fact_loans",
     "annual income below 5,000 or above 1,000,000, flagged"),
    ("rate_anomalies", "WARN",
     "select count(*) filter (where is_rate_anomaly) from mart.fact_loans",
     "interest rate of exactly 6.00 percent in grades B to G, flagged as a likely data error"),
    ("over_credit_limit", "WARN",
     "select count(*) filter (where is_over_credit_limit) from mart.fact_loans",
     "revolving utilisation above 100 percent, flagged"),
    ("partially_funded", "WARN",
     "select count(*) filter (where is_partially_funded) from mart.fact_loans",
     "installment below the payment on the requested amount: loan was partially funded"),
    ("missing_mort_acc", "WARN",
     "select count(*) from mart.fact_loans where mortgage_accounts is null",
     "mortgage_accounts is blank for loans issued before 2013, when the field was not collected"),
    ("incomplete_recent_cohorts", "WARN",
     "select count(*) from mart.fact_loans where not is_mature_cohort",
     "loans whose full term had not ended by Dec 2016: only resolved loans are in the data, so these cohorts are biased"),
]


def run() -> bool:
    con = duckdb.connect(str(DB_PATH))
    con.execute(
        """create or replace table mart.data_quality_results (
               check_name varchar, severity varchar, violations bigint,
               status varchar, description varchar, run_at timestamp)"""
    )

    failed = False
    for name, severity, sql, description in CHECKS:
        violations = int(con.execute(sql).fetchone()[0])
        if violations == 0:
            status = "PASS"
        else:
            status = "FAIL" if severity == "FAIL" else "WARN"
        failed = failed or status == "FAIL"
        print(f"  {status:<4}  {name:<26} {violations:>10,}")
        con.execute(
            "insert into mart.data_quality_results values (?, ?, ?, ?, ?, now())",
            [name, severity, violations, status, description],
        )
    con.close()
    return not failed


if __name__ == "__main__":
    sys.exit(0 if run() else 1)
