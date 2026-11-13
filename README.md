# LoanLens: Loan Portfolio and Credit Risk Analytics

An end-to-end analytics project: a quality-checked DuckDB warehouse (star schema, dbt-style SQL) feeding a three-page Power BI dashboard on loan portfolio performance and credit risk.

## The question

Which borrowers and loan types carry the most credit risk, and how much would expected losses rise if defaults worsened?

## Headline results

Figures below come from the exploratory analysis in [`docs/eda.md`](docs/eda.md) and the stress test on page 3 of the dashboard. Every figure can be checked against the Reconciliation sheet of [`docs/LoanLens_KPI_Workbook.xlsx`](docs/LoanLens_KPI_Workbook.xlsx).

- **Portfolio:** 396,030 loans, $5.59B total loan amount, 19.61% overall default rate.
- **Risk climbs with grade:** default rate runs from 6.29% for grade A to 47.84% for grade G (2.87% for A1 to about 50% for G3–G5).
- **Term doubles the risk:** 15.77% for 36-month loans against 31.94% for 60-month loans. 60-month loans are 24% of loans but 39% of defaults.
- **Debt-to-income:** 13.72% below 10, rising to 32.45% at 30 and above.
- **Like-for-like baseline:** loans whose full term had ended (the mature cohort, 37% of loans) default at 12.95%. Later cohorts are distorted because only finished loans are in the data.
- **Stress test:** at an assumed 45% loss given default, base expected loss is about $520M. A 2-point rise in every grade's default rate adds about $50M (+9.7%), and a 5-point rise adds about $126M (+24%). Because the shock is added to each grade, the increase is simply total loan amount × shock × LGD.

## Architecture

```
lending_club_loan_two.csv
        |
        v
  raw.loans            everything loaded as text, nothing lost
        |
        v
  stg.loans            typed, standardised, flagged
  stg.rejected_loans   rows that fail hard rules, with a reason
  stg.valid_loans      rows that pass
        |
        v
  mart.fact_loans + 8 dimensions     (star schema)
  mart.data_quality_results          result of every quality check
        |
        v
  data/exports/*.parquet   ->   Power BI (3 pages)
```

Outliers and anomalies are **flagged, not removed**, so portfolio totals always reconcile to the source file. Profiling found no rows that break a hard rule, so `stg.rejected_loans` is expected to be empty; it exists so that a bad future file fails visibly instead of silently.

The SQL follows the dbt style: import CTEs at the top, one logical step per CTE, and a final `SELECT`. Each file ends in a single `CREATE OR REPLACE TABLE ... AS`, so any file could become a dbt model with minimal change.

## Dashboard

Three pages, each with slicers for issue year, grade and term, and a page navigator.

1. **Executive Summary:** cards for total loan amount, loan count, average loan amount, default rate and average interest rate; loans issued and default rate by issue year (columns and line); loan amount by grade.
2. **Portfolio Quality:** cards for default rate, charged-off loan amount, average debt-to-income and share of 60-month loans; default rate by loan term, debt-to-income band, income band and issue year.
3. **Risk and Segments:** default rate by grade and by purpose; loan amount by purpose (treemap) to show where exposure is concentrated; loans by home ownership and by income verification; and the stress test, a column chart of base and stressed expected loss by grade, driven by two what-if sliders: default shock (0 to 5 points) and loss given default.

The issue-year charts include every cohort, so read 2014–2016 with the cohort caveat under [Assumptions and limitations](#assumptions-and-limitations). Every KPI, its DAX, the chart it feeds and its caveats are documented in [`docs/LoanLens_KPI_Workbook.xlsx`](docs/LoanLens_KPI_Workbook.xlsx), which also holds the expected values to reconcile against and a live Excel copy of the stress test. The wireframe came first, and the dashboard follows its layout.

## Folder structure

```
loanlens/
├── README.md
├── Makefile                      shortcuts for every step (build, checks, EDA)
├── pyproject.toml                dependencies (managed with uv)
├── uv.lock
├── .gitignore
├── data/
│   ├── raw/                      put lending_club_loan_two.csv here (not committed)
│   ├── warehouse/                loanlens.duckdb is created here (not committed)
│   └── exports/                  parquet and csv for Power BI (not committed)
├── sql/
│   ├── 01_raw.sql                warehouse logic, in run order
│   ├── 02_staging.sql
│   ├── 03_dimensions.sql
│   ├── 04_fact.sql
│   ├── checks/                   data quality checks on raw.loans
│   └── eda/                      exploratory analysis queries
├── pipeline/                     python that runs the SQL and the checks
│   ├── config.py
│   ├── profile_raw.py
│   ├── build_warehouse.py
│   ├── quality_checks.py
│   ├── export_for_powerbi.py
│   └── run_pipeline.py
├── src/loanlens/                 package entry point
├── powerbi/
│   ├── LoanLens.pbix             the three-page report
│   ├── dax/measures.dax          every measure, relationship and what-if parameter
│   └── theme/loanlens_theme.json report theme
└── docs/
    ├── data_dictionary.md        columns, types, cleaning rules, quality check results
    ├── eda.md                    exploratory analysis and the staging decisions it led to
    ├── raw_profile.md            generated by profile_raw.py
    ├── LoanLens_KPI_Workbook.xlsx  every KPI and its DAX, expected values, stress test calculator
    └── screenshots/              (planned) dashboard images for this README
```

## How to run

Requires Python 3.13 and [uv](https://docs.astral.sh/uv/).

```bash
uv sync                                    # create .venv and install dependencies

# put lending_club_loan_two.csv in data/raw/
make profile                               # optional: see what the data holds
uv run python pipeline/run_pipeline.py     # build, check, export
```

Build one layer at a time with `uv run python pipeline/build_warehouse.py --through N` (1 = raw, 2 = staging, 3 = dimensions, 4 = fact). `make build-raw` builds the raw layer only.

Inspect the data:

```bash
make checks      # all six data quality checks on raw.loans
make eda         # every exploratory query, in order
make eda-grade   # or any single query: see the Makefile for the full list
```

Then in Power BI Desktop (Windows). If you work in WSL, `make export-windows` first copies the parquet files somewhere Windows can read them.

**Open the finished report:** open `powerbi/LoanLens.pbix`, go to Transform data > Data source settings, point each source at your copy of `data/exports/`, and refresh.

**Or rebuild it from scratch:**

1. Get Data > Parquet, and load every file in `data/exports/`.
2. Create the relationships listed at the top of `powerbi/dax/measures.dax`.
3. Create the two what-if parameters and a `_Measures` table, then add the measures.
4. Import `powerbi/theme/loanlens_theme.json` (View > Themes > Browse for themes).

Check the cards against the Reconciliation sheet of `docs/LoanLens_KPI_Workbook.xlsx`.

## Data quality

Quality is checked in two places:

1. **Profiling checks** (`sql/checks/`, `make checks`) on the raw data: missing values, type conversion, allowed values, ranges, outliers and cross-column consistency. Results are written up in [`docs/data_dictionary.md`](docs/data_dictionary.md).
2. **Pipeline checks** (`pipeline/quality_checks.py`) after every build: 16 checks, stored in `mart.data_quality_results`. The pipeline stops if a hard check fails, and nothing is exported.

**8 hard checks (stop the pipeline):** all pass on the current data.

| Check | Rule |
|---|---|
| `row_conservation` | raw rows = fact rows + rejected rows |
| `loan_id_unique` | one fact row per loan |
| `no_null_foreign_keys` | every fact row joins to every dimension |
| `loan_amount_positive` | requested amounts are present and positive |
| `interest_rate_in_range` | interest rate between 0 and 40% |
| `status_values_known` | only Fully Paid and Charged Off reach the fact table |
| `default_flag_binary` | default flag is 0 or 1 |
| `grades_valid` | grades are A to G |

**8 warnings (documented, not hidden):** loans are flagged in `mart.fact_loans`, never removed.

| Check | Loans | Meaning |
|---|---|---|
| `rejected_rows` | 0 | rows rejected in staging (see `stg.rejected_loans`) |
| `dti_outliers` | 7 | debt-to-income above 100 (the one 9999 placeholder is set to NULL) |
| `income_outliers` | 80 | annual income below 5k (15) or above 1M (65) |
| `rate_anomalies` | 68 | interest rate of exactly 6.00% in grades B–G, a likely data error |
| `over_credit_limit` | 1,167 | revolving utilisation above 100% |
| `partially_funded` | 1,566 | installment below the payment on the requested amount |
| `missing_mort_acc` | 37,795 | blank for loans issued before 2013, when the field was not collected |
| `incomplete_recent_cohorts` | 248,704 | full term not ended by Dec 2016 (see limitations) |

## Assumptions and limitations

- **Default means Charged Off.** The data has only two loan statuses, Fully Paid and Charged Off, so there is no late or current-loan view.
- **Recent cohorts are biased.** Only loans that already finished are present. Charge-offs happen early and full repayment takes the whole term, so default rates are inflated for 2014–2015 and deflated for 2016. Loans are flagged as a *mature cohort* when their full term ended by December 2016 (36-month loans issued up to 2013, 60-month loans up to 2011); trend visuals use this flag.
- **Loan amount is the exposure, with a caveat.** `requested_amount` (`loan_amnt` in the source) is the amount applied for. 1,566 loans, mostly from 2008–2011, were only partially funded, so their exposure is slightly overstated. There is no funded amount or outstanding balance.
- **Loss given default is an assumption.** The data has no recoveries, so the stress test treats it as an adjustable input. The 45% starting value is a placeholder, not a result.
- **Address is excluded.** It is synthetic: 396,030 loans share only 10 ZIP codes, and states are unrelated to ZIP. Worse, **ZIP leaks the outcome**: three ZIP codes contain only charged-off loans and three only fully paid loans. Using it would be target leakage.
- **Findings are single-factor comparisons.** Grade, interest rate, term and purpose overlap, so their effects are not additive.
- **Expected loss is an estimate.** It is calculated grade by grade, and it is neither a forecast nor a regulatory calculation.
- **This is public data, not data from a real bank.**

## Stack

Python 3.13, uv, DuckDB, SQL (dbt-style CTEs), Parquet, Power BI (DAX).

## Data source

`lending_club_loan_two.csv`: 396,030 loans issued June 2007 to December 2016, from a public Lending Club dataset on Kaggle. Not committed to this repository.
