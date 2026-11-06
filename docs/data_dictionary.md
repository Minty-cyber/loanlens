# LoanLens Data Dictionary

## Source

| | |
|---|---|
| Dataset | LendingClub loan data (Kaggle, `lending_club_loan_two.csv`) |
| Location | `data/raw/lending_club_loan_two.csv` (not versioned) |
| Grain | One row per funded loan |
| Rows | 396,030 |
| Columns | 27 |
| Issue period | Jun 2007 – Dec 2016 |
| Target | `loan_status` (`Fully Paid` / `Charged Off`) |

The file contains only **finished** loans (fully paid or charged off). Loans still being repaid are
not included, so recent issue years (especially 2016) over-represent loans that ended early.

## Columns

Raw type is what DuckDB infers from the CSV. Target type is what the staging layer will cast to.
Nulls are counted on `raw.loans` with `sql/checks/null_check.sql` (0.00 = no nulls). Cleaning rules are **proposed** and will be confirmed
during EDA.

### Loan

| Column | Description | Raw type | Target type | Nulls | Example | Cleaning rule (proposed) |
|---|---|---|---|---|---|---|
| `loan_amnt` | Amount the borrower applied for (USD) | DOUBLE | DECIMAL(12,2) | 0.00 | `10000.0` | Cast. Range 500 – 40,000 |
| `term` | Number of monthly payments | VARCHAR | INTEGER | 0.00 | `" 36 months"` | Trim, extract number (36 or 60) |
| `int_rate` | Annual interest rate (%) | DOUBLE | DECIMAL(5,2) | 0.00 | `10.99` | Cast. Range 5.32 – 30.99. Flag `= 6.00` (70 loans in grades B–G, implausible) |
| `installment` | Monthly payment owed | DOUBLE | DECIMAL(12,2) | 0.00 | `327.34` | Cast. Derived from amount, rate and term; ~1,550 early loans reflect a partially funded amount |
| `grade` | LendingClub risk grade, A (lowest risk) to G (highest) | VARCHAR | VARCHAR(1) | 0.00 | `B` | Keep. 7 values |
| `sub_grade` | Finer risk grade, A1 – G5 | VARCHAR | VARCHAR(2) | 0.00 | `B3` | Keep. 35 values |
| `purpose` | Borrower-selected loan category | VARCHAR | VARCHAR | 0.00 | `debt_consolidation` | Keep. 14 values; consider grouping small categories |
| `title` | Free-text loan title entered by the borrower | VARCHAR | — | 1,755 (0.44%) | `Debt consolidation` | Drop. Messy duplicate of `purpose`; 5 null-like text values |
| `issue_d` | Month the loan was funded | VARCHAR | DATE | 0.00 | `Oct-2014` | `strptime(issue_d, '%b-%Y')` → first day of month |
| `initial_list_status` | Investor market: `w` = whole, `f` = fractional | VARCHAR | VARCHAR(1) | 0.00 | `f` | Keep |
| `application_type` | Individual or joint application | VARCHAR | VARCHAR | 0.00 | `INDIVIDUAL` | Keep. 99.8% `INDIVIDUAL` |

### Borrower

| Column | Description | Raw type | Target type | Nulls | Example | Cleaning rule (proposed) |
|---|---|---|---|---|---|---|
| `emp_title` | Job title (free text) | VARCHAR | — | 22,927 (5.79%) | `Teacher` | Drop. ~166k inconsistent values (`RN` vs `Registered Nurse`); 3 null-like text values |
| `emp_length` | Years in current job | VARCHAR | INTEGER | 18,301 (4.62%) | `10+ years` | `< 1 year` → 0, `10+ years` → 10, else the number. Keep NULL |
| `home_ownership` | Housing status | VARCHAR | VARCHAR | 0.00 | `MORTGAGE` | Group `OTHER`, `NONE`, `ANY` (146 rows) into `OTHER`. `NONE` (31 rows) is a real category, not missing |
| `annual_inc` | Self-reported annual income (USD) | DOUBLE | DECIMAL(14,2) | 0.00 | `60000.0` | Cast. Flag `< 5,000` (15 rows, incl. 1 zero) and `> 1M` (65 rows). Median 64k, p99 250k, max 8.7M |
| `verification_status` | Whether LendingClub verified the income (`Verified`) or its source (`Source Verified`) | VARCHAR | VARCHAR | 0.00 | `Verified` | Keep. 3 values |
| `dti` | Monthly debt payments (excl. mortgage and this loan) ÷ monthly income × 100 | DOUBLE | DECIMAL(7,2) | 0.00 | `16.8` | 9999 is a placeholder (1 row) → NULL. Flag remaining values > 100 (7 rows). Median 16.9, p99 36.4 |

### Credit history

| Column | Description | Raw type | Target type | Nulls | Example | Cleaning rule (proposed) |
|---|---|---|---|---|---|---|
| `earliest_cr_line` | Month the borrower's first credit line was opened | VARCHAR | DATE | 0.00 | `Oct-2000` | `strptime(..., '%b-%Y')`. Derive credit age at issue |
| `open_acc` | Number of currently open credit lines | DOUBLE | INTEGER | 0.00 | `9` | Cast. Never exceeds `total_acc` |
| `total_acc` | Total credit lines ever opened | DOUBLE | INTEGER | 0.00 | `21` | Cast |
| `revol_bal` | Total revolving balance owed (USD) | DOUBLE | DECIMAL(14,2) | 0.00 | `5655.0` | Cast. Highly skewed (max 1.7M) |
| `revol_util` | Share of available revolving credit in use (%) | DOUBLE | DECIMAL(6,2) | 276 (0.07%) | `53.0` | Cast. Flag values > 100 (1,167 rows, 0.3%); > 150 (4 rows) is suspect. Median 54.8, p99 98, max 892.3 |
| `pub_rec` | Number of derogatory public records | DOUBLE | INTEGER | 0.00 | `0` | Cast |
| `pub_rec_bankruptcies` | Number of bankruptcies on record | DOUBLE | INTEGER | 535 (0.14%) | `0` | Cast. Keep NULL |
| `mort_acc` | Number of mortgage accounts | DOUBLE | INTEGER | 37,795 (9.54%) | `0` | Cast. Keep NULL (unknown ≠ zero) |

### Outcome and other

| Column | Description | Raw type | Target type | Nulls | Example | Cleaning rule (proposed) |
|---|---|---|---|---|---|---|
| `loan_status` | Final outcome of the loan | VARCHAR | VARCHAR | 0.00 | `Fully Paid` | Keep. Derive `is_default = loan_status = 'Charged Off'` |
| `address` | Street, city, state and ZIP | VARCHAR | — | 0.00 | `0174 Michelle Gateway\nMendozaberg, OK 22690` | Drop. Synthetic: 10 ZIPs, states unrelated to ZIP, and ZIP leaks the target (see EDA §7) |

## Missing values

Checked with `sql/checks/null_check.sql` on `raw.loans` (396,030 rows):

- Missing data is always a real `NULL`. No column contains empty or whitespace-only strings.
- Only six columns have nulls: `mort_acc`, `emp_title`, `emp_length`, `title`,
  `pub_rec_bankruptcies`, `revol_util`.
- Null-like text (`NA`, `None`, …) appears only in the free-text columns `emp_title` (3) and
  `title` (5), which are dropped. `home_ownership` = `NONE` matches the pattern but is a valid
  category.
- Staging therefore needs no string-to-NULL replacement; casts can be applied directly.

## Type conversion

Checked with `sql/checks/type_check.sql` on `raw.loans`. Every non-null value was tested against
its target type; **0 failures in all 16 columns**.

| Rule | Columns | Test | Failed |
|---|---|---|---|
| DECIMAL | `loan_amnt`, `int_rate`, `installment`, `annual_inc`, `dti`, `revol_bal`, `revol_util` | Value is numeric | 0 |
| INTEGER | `open_acc`, `total_acc`, `pub_rec`, `mort_acc`, `pub_rec_bankruptcies` | Value is numeric and whole (stored as e.g. `9.0`) | 0 |
| DATE | `issue_d`, `earliest_cr_line` | Parses with `strptime(..., '%b-%Y')` | 0 |
| TERM | `term` | Matches `N months` after trimming | 0 |
| EMP_LENGTH | `emp_length` | One of `< 1 year`, `1 year`, `2 years` … `9 years`, `10+ years` | 0 |

Values checked per column equal 396,030 minus that column's nulls, which agrees with the missing
values check.

Staging can therefore use `cast()` rather than `try_cast()`, so an unexpected value in a future
file fails the build instead of silently becoming `NULL`.

## Allowed values

Checked with `sql/checks/allowed_values_check.sql` on `raw.loans`. Each category column was compared
(after trimming) against its expected list.

| Column | Expected values | Distinct in data | Unexpected rows | Untrimmed rows |
|---|---|---|---|---|
| `application_type` | 3 | 3 | 0 | 0 |
| `grade` | 7 | 7 | 0 | 0 |
| `home_ownership` | 6 | 6 | 0 | 0 |
| `initial_list_status` | 2 | 2 | 0 | 0 |
| `loan_status` | 2 | 2 | 0 | 0 |
| `purpose` | 14 | 14 | 0 | 0 |
| `sub_grade` | 35 (A1 – G5) | 35 | 0 | 0 |
| `term` | 2 | 2 | 0 | 396,030 |
| `verification_status` | 3 | 3 | 0 | 0 |

- No unexpected values in any category column.
- Every expected value occurs at least once, so each dimension will have no unused members.
- `term` is the only column needing `trim()`; every row has a leading space.
- `emp_length` was validated against its 11 values in the type conversion check.
- `sub_grade` starts with its `grade` on every row (0 mismatches out of 396,030), so `grade` can be
  derived from `sub_grade` and the two form a clean hierarchy for `dim_grade`.

## Ranges and outliers

Checked with `sql/checks/range_check.sql` (distribution) and `sql/checks/outlier_check.sql`
(plausibility rules) on `raw.loans`.

### Distribution

| Column | Min | p01 | Median | Mean | p99 | Max |
|---|---|---|---|---|---|---|
| `loan_amnt` | 500 | 1,600 | 12,000 | 14,114 | 35,000 | 40,000 |
| `int_rate` | 5.32 | 6.00 | 13.33 | 13.64 | 25.28 | 30.99 |
| `installment` | 16.08 | 54.43 | 375.43 | 431.85 | 1,202.37 | 1,533.81 |
| `annual_inc` | 0 | 19,000 | 64,000 | 74,203 | 250,000 | 8,706,582 |
| `dti` | 0 | 1.56 | 16.91 | 17.38 | 36.43 | 9,999 |
| `revol_bal` | 0 | 154 | 11,181 | 15,845 | 86,040 | 1,743,266 |
| `revol_util` | 0 | 1.0 | 54.8 | 53.79 | 98.0 | 892.3 |
| `open_acc` | 0 | 3 | 10 | 11.31 | 27 | 90 |
| `total_acc` | 2 | 6 | 24 | 25.41 | 60 | 151 |
| `pub_rec` | 0 | 0 | 0 | 0.18 | 2 | 86 |
| `pub_rec_bankruptcies` | 0 | 0 | 0 | 0.12 | 1 | 8 |
| `mort_acc` | 0 | 0 | 1 | 1.81 | 9 | 34 |

- Loan terms (`loan_amnt`, `int_rate`, `installment`) are bounded and clean: no values outside
  LendingClub's product limits.
- Borrower and credit-history columns are right-skewed: the mean sits above the median and the
  max is far beyond p99 (`annual_inc`, `revol_bal`, `dti`, `pub_rec`). Bands should use fixed
  cut-offs with an open-ended top band, not averages.

### Plausibility rules

| Rule | Rows | % | Interpretation |
|---|---|---|---|
| `revol_util` > 100% | 1,167 | 0.295 | Possible (fees/interest over limit); flag |
| `dti` = 0 | 313 | 0.079 | Plausible (no other debt); keep |
| `annual_inc` > 1M | 65 | 0.016 | Likely entry errors; flag |
| `pub_rec` > 10 | 23 | 0.006 | Extreme but possible; keep |
| `annual_inc` < 5,000 | 15 | 0.004 | Likely entry errors (incl. 1 zero); flag |
| `loan_amnt` < 1,000 | 10 | 0.003 | Valid early-era small loans; keep |
| `dti` > 100 | 8 | 0.002 | Includes the 9999 placeholder; flag the other 7 |
| `open_acc` = 0 | 6 | 0.002 | Plausible; keep |
| `revol_util` > 150% | 4 | 0.001 | Suspect; flag |
| `dti` = 9999 | 1 | 0.000 | Placeholder; set to NULL |
| `annual_inc` = 0 | 1 | 0.000 | Entry error; flag |
| `int_rate` outside 5 – 31% | 0 | 0.000 | — |
| Any negative value | 0 | 0.000 | — |

All outliers together are under 0.4% of loans. **Loans are flagged, not removed**, so portfolio
totals in the report still reconcile to the source file.

## Consistency

Checked with `sql/checks/consistency_check.sql` on `raw.loans`.

| Rule | Rows | % | Interpretation |
|---|---|---|---|
| Installment off the payment formula by > $1 | 1,604 | 0.405 | 70 are the 6.00% rate anomaly; 1,547 have a *lower* installment (median 67% of expected), concentrated in 2008–2011: these loans were partially funded |
| Installment off the payment formula by > 5% | 1,508 | 0.381 | Same loans as above |
| Total repayments < amount applied for | 1,095 | 0.276 | Same cause: repayments are based on the funded amount |
| `revol_bal` > 0 but `revol_util` = 0 | 363 | 0.092 | Minor reporting inconsistency; keep |
| `revol_bal` = 0 but `revol_util` > 0 | 55 | 0.014 | Minor reporting inconsistency; keep |
| First credit line on/after issue date | 0 | 0 | — |
| Credit history < 1 year at issue | 0 | 0 | Shortest credit history is 3 years |
| `open_acc` > `total_acc` | 0 | 0 | — |
| Bankruptcies > public records | 0 | 0 | — |

- `loan_amnt` is the amount **applied for**. The funded amount is not in this file, so
  `installment` cannot be reconciled for partially funded loans.
- 70 loans have `int_rate` = 6.00% in grades B–G, far below those grades' normal ranges. Treated
  as a data error and flagged.

## Known data issues

| Issue | Columns | Rows affected | Proposed handling |
|---|---|---|---|
| Leading space in values | `term` | All | Trim |
| Dates stored as `Mon-YYYY` text | `issue_d`, `earliest_cr_line` | All | Parse with `strptime` (all values parse) |
| Placeholder value | `dti` = 9999 | 1 | Set to NULL |
| Implausible income | `annual_inc` < 5,000 / > 1M | 15 / 65 | Flag; keep the loan |
| Over-limit utilisation | `revol_util` > 100 / > 150 | 1,167 / 4 | Flag; keep the loan |
| Extreme debt-to-income | `dti` > 100 (excl. 9999) | 7 | Flag; keep the loan |
| Rare categories | `home_ownership` | 146 | Group into `OTHER` |
| Synthetic location, target leakage | `address` (ZIP) | All | Exclude: 3 ZIPs are 100% charged off, 3 are 0% |
| Implausible interest rate | `int_rate` = 6.00 in grades B–G | 70 | Flag; keep the loan |
| Partially funded loans | `installment` vs `loan_amnt` | ~1,550 (mostly 2008–2011) | Note; `loan_amnt` is the amount applied for |
| Utilisation inconsistent with balance | `revol_bal` > 0 with `revol_util` = 0, and the reverse | 363 / 55 | Note; keep as-is |
| Incomplete recent cohorts | `issue_d` after 2013 (36-month), after 2011 (60-month) | 248,704 | Add `is_mature_cohort` (EDA §1) |
| Null-like text | `emp_title`, `title` | 3 / 5 | None needed (both columns dropped) |
| Duplicate rows | — | 0 | None needed |
