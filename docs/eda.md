# LoanLens Exploratory Data Analysis

## Purpose

Find out what drives a LendingClub loan to be **charged off**, and turn each finding into a
decision for the staging layer and the Power BI model.

| | |
|---|---|
| Source | `raw.loans` (396,030 loans, Jun 2007 – Dec 2016) |
| Target | `loan_status` = `Charged Off` (default) vs `Fully Paid` |
| Baseline default rate | **19.61%** (77,673 loans) |
| Queries | `sql/eda/*.sql`, run with `make eda` (or one target, e.g. `make eda-grade`) |
| Data quality | See `docs/data_dictionary.md` |

**Lift** in the tables below is a group's default rate divided by the baseline: 1.5 means 50% more
likely to default than the average loan, 0.5 means half as likely.

## Summary

1. **Grade, interest rate and term** are the strongest drivers. Default rises steadily from 2.9%
   (A1) to about 50% (G3–G5), and 60-month loans default twice as often as 36-month loans.
2. **Debt-to-income, revolving utilisation, income, home ownership and mortgage accounts** add
   moderate signal, each moving default by roughly ±20–60% around the baseline.
3. **Employment length, credit age, account counts, revolving balance, public records and
   listing status** barely move default.
4. **Yearly default rates after 2013 are distorted**: the file only holds finished loans. A
   mature-cohort flag is needed for like-for-like comparisons.
5. **ZIP code leaks the target** (three ZIPs default 100%, three 0%) and must be excluded.
   The addresses are synthetic.
6. Data issues found along the way: 70 loans with an implausible 6.00% rate, and ~1,550 early
   loans that were only partially funded.

## 1. Target

Queries: `01_target_overall.sql`, `01_target_by_year.sql`, `01_target_mature_cohort.sql`

| Term | Loans | Charged off | Default rate | Funded (M USD) |
|---|---|---|---|---|
| 36 months | 302,005 | 47,640 | 15.77% | 3,707.8 |
| 60 months | 94,025 | 30,033 | **31.94%** | 1,881.7 |
| All | 396,030 | 77,673 | 19.61% | 5,589.5 |

- 60-month loans are 24% of loans but 34% of money lent and **39% of all defaults**.
- 60-month loans first appear in 2010; earlier years are 36-month only.

| Issue year | Loans | % 60-month | Default rate | 36-month | 60-month |
|---|---|---|---|---|---|
| 2007 | 195 | 0.0 | 16.41% | 16.41% | — |
| 2008 | 1,240 | 0.0 | 15.81% | 15.81% | — |
| 2009 | 3,826 | 0.0 | 12.26% | 12.26% | — |
| 2010 | 9,258 | 26.3 | 13.21% | 10.41% | 21.04% |
| 2011 | 17,435 | 35.1 | 15.25% | 10.58% | 23.86% |
| 2012 | 41,202 | 15.0 | 16.48% | 13.43% | 33.68% |
| 2013 | 97,662 | 17.7 | 15.74% | 12.18% | 32.27% |
| 2014 | 102,860 | 26.2 | **23.11%** | 18.94% | 34.88% |
| 2015 | 94,264 | 29.6 | **24.90%** | 20.65% | 35.01% |
| 2016 | 28,088 | 25.4 | **13.13%** | 11.73% | 17.24% |

**Interpretation.** The jump in 2014–2015 followed by a collapse in 2016 is what survivorship
bias produces when only finished loans are kept. Charge-offs happen early in a loan's life, while
full repayment takes the whole term. For 2014–2015, early charge-offs are in the file but many
loans still being repaid are not, which inflates the rate. For 2016, mostly early payoffs have
finished, which deflates it. The rise also appears within 36-month loans alone, so it is not
caused by the term mix. This file has no snapshot or last-payment date, so the effect cannot be
removed exactly, only isolated.

| Cohort | Loans | % of loans | Default rate |
|---|---|---|---|
| Mature (full term ended by Dec 2016) | 147,326 | 37.2 | **12.95%** |
| Not mature | 248,704 | 62.8 | 23.56% |

A loan is *mature* when `issue_date + term ≤ Dec 2016`, the latest issue month and therefore
the earliest possible snapshot date: 36-month loans issued up to Dec 2013 and 60-month loans
issued up to Dec 2011.

**Decision.** Add `is_mature_cohort` to `fact_loans`. Use it as a report filter for trend and
cohort comparisons. Portfolio totals keep all loans.

## 2. Loan terms

Queries: `02_grade.sql`, `02_sub_grade.sql`, `02_loan_bands.sql`

| Grade | Loans | Default rate | Lift | 36-month | 60-month | % 60-month | Avg rate |
|---|---|---|---|---|---|---|---|
| A | 64,187 | 6.29% | 0.32 | 6.22% | 9.17% | 2.3 | 7.39% |
| B | 116,018 | 12.57% | 0.64 | 12.06% | 17.14% | 10.1 | 11.22% |
| C | 105,987 | 21.18% | 1.08 | 19.69% | 25.64% | 25.1 | 14.32% |
| D | 63,524 | 28.87% | 1.47 | 25.71% | 34.68% | 35.2 | 17.48% |
| E | 31,488 | 37.36% | 1.91 | 33.04% | 39.88% | 63.2 | 20.28% |
| F | 11,772 | 42.79% | 2.18 | 38.22% | 44.01% | 78.9 | 23.70% |
| G | 3,054 | 47.84% | 2.44 | 47.06% | 47.95% | 87.8 | 25.90% |

- Default rises with every grade step, and almost every sub-grade step: from **2.87% (A1)** to
  around **50% (G3–G5)**. Below grade F, sub-grades become noisy because they hold few loans
  (G5: 316).
- Term still matters *within* a grade: 60-month loans default more in every grade. But the risky
  grades are mostly 60-month (88% of G), so part of the term effect is grade mix.
- **Interest rate** is LendingClub's price for the same risk: default climbs from 5.7% (< 8%) to
  43.2% (23%+).
- **Loan amount** has a weak effect: 16.2% (< 5k) to 23.7% (30k+).
- **Anomaly:** 70 loans have an interest rate of exactly **6.00%** in grades B–G, far below
  those grades' normal ranges (e.g. grade D averages 17.5%). Almost certainly a data error.

**Decisions.**
- `dim_grade`: one row per sub-grade with its grade, for drill-down from grade to sub-grade.
- Add an interest-rate band attribute (`< 8%` … `23%+`, as above) to the fact or a small dimension.
- Flag `int_rate = 6.00` as a rate anomaly in `data_quality_results`; keep the loans.

## 3. Borrower

Queries: `03_borrower_bands.sql`, `03_borrower_categories.sql`

| Income band | Loans | Default rate | Lift |
|---|---|---|---|
| < 5k (flag) | 15 | 40.00% | 2.04 |
| 5k–40k | 63,502 | 24.69% | 1.26 |
| 40k–60k | 108,327 | 21.71% | 1.11 |
| 60k–80k | 91,440 | 19.37% | 0.99 |
| 80k–100k | 56,884 | 16.70% | 0.85 |
| 100k–150k | 54,059 | 15.10% | 0.77 |
| 150k+ | 21,803 | 14.20% | 0.72 |

| DTI band | Loans | Default rate | Lift |
|---|---|---|---|
| 0–10 | 78,954 | 13.72% | 0.70 |
| 10–20 | 172,697 | 17.50% | 0.89 |
| 20–30 | 116,044 | 23.64% | 1.21 |
| 30+ | 28,334 | 32.45% | 1.65 |
| 9999 placeholder | 1 | — | — |

| Category | Value | Loans | Default rate | Lift |
|---|---|---|---|---|
| `home_ownership` | MORTGAGE | 198,348 | 16.96% | 0.86 |
| | RENT | 159,790 | 22.66% | 1.16 |
| | OWN | 37,746 | 20.68% | 1.05 |
| | OTHER / NONE / ANY | 146 | ~16% | — |
| `verification_status` | Not Verified | 125,082 | 14.64% | 0.75 |
| | Source Verified | 131,385 | 21.47% | 1.09 |
| | Verified | 139,563 | 22.32% | 1.14 |
| `emp_length` | < 1 year … 10+ years | 377,729 | 18.4% – 20.7% | 0.94 – 1.05 |
| | NULL | 18,301 | **27.53%** | **1.40** |
| `application_type` | INDIVIDUAL | 395,319 | 19.61% | 1.00 |
| | JOINT | 425 | 12.71% | 0.65 |
| | DIRECT_PAY | 286 | 35.66% | 1.82 |

- **Income** and **DTI** both have a clean, monotonic effect: lower income and higher DTI mean
  more defaults. The 30–40 and 40+ DTI bands default at the same rate (32.5% vs 32.2%), so they
  can be merged.
- **Renters** default more than people with a mortgage (22.7% vs 17.0%).
- **Verified income defaults more than unverified.** This looks backwards, but LendingClub
  verifies applicants it already considers riskier or who borrow more, so verification likely
  stands in for grade and loan size. Not tested here; treat it as a correlation, not a cause.
- **Employment length has almost no effect** once known (18.4%–20.7%). **Missing** employment
  length is a real warning sign (27.5%), and it occurs across all years.
- `application_type` groups other than INDIVIDUAL are too small (711 loans) to rely on.

**Decisions.**
- `dim_income_band`: `< 40k`, `40k–60k`, `60k–80k`, `80k–100k`, `100k–150k`, `150k+`. Flag
  incomes `< 5k` and `> 1M` in `data_quality_results`.
- `dim_dti_band`: `0–10`, `10–20`, `20–30`, `30+`. Set `dti = 9999` to NULL (shown as
  `Unknown`).
- `dim_home_ownership`: `MORTGAGE`, `RENT`, `OWN`, `OTHER` (merging `OTHER`, `NONE`, `ANY`).
- `emp_length`: keep as a number of years, with NULL shown as `Unknown` and kept as its own
  group because it carries signal.

## 4. Purpose

Query: `04_purpose.sql`

| Purpose | Loans | % loans | Default rate | Lift | Avg amount | Avg rate |
|---|---|---|---|---|---|---|
| debt_consolidation | 234,507 | 59.21 | 20.74% | 1.06 | 14,879 | 13.94% |
| credit_card | 83,019 | 20.96 | 16.71% | 0.85 | 14,482 | 12.36% |
| home_improvement | 24,030 | 6.07 | 17.01% | 0.87 | 14,114 | 13.15% |
| other | 21,185 | 5.35 | 21.22% | 1.08 | 9,629 | 15.24% |
| major_purchase | 8,790 | 2.22 | 16.47% | 0.84 | 10,929 | 12.66% |
| small_business | 5,701 | 1.44 | **29.45%** | **1.50** | 15,387 | 15.96% |
| car | 4,697 | 1.19 | 13.48% | 0.69 | 8,221 | 11.87% |
| medical | 4,196 | 1.06 | 21.71% | 1.11 | 8,955 | 14.84% |
| moving | 2,854 | 0.72 | 23.48% | 1.20 | 7,874 | 15.67% |
| vacation | 2,452 | 0.62 | 18.92% | 0.96 | 6,220 | 14.60% |
| house | 2,201 | 0.56 | 19.72% | 1.01 | 15,395 | 15.62% |
| wedding | 1,812 | 0.46 | 12.09% | 0.62 | 10,232 | 14.00% |
| renewable_energy | 329 | 0.08 | 23.40% | 1.19 | 9,352 | 14.98% |
| educational | 257 | 0.06 | 16.34% | 0.83 | 6,821 | 11.69% |

- Debt consolidation and credit card refinancing are 80% of loans.
- **Small business** loans are the riskiest purpose (29.5%); car and wedding loans the safest.
- Purposes with low default also tend to have low rates, so part of the gap is grade mix.

**Decision.** `dim_purpose` keeps all 14 values with a readable label (e.g. `debt_consolidation`
→ "Debt consolidation"). The small purposes behave differently enough (small business vs
wedding) that grouping them would hide signal; the report can show the top purposes and group the
rest visually.

## 5. Credit history

Queries: `05_credit_history.sql`, `05_missingness.sql`

| Feature | Lowest-risk band | Highest-risk band | Effect |
|---|---|---|---|
| `revol_util` | 0–20%: 13.05% | > 100%: 30.33% | **Strong, monotonic** |
| `mort_acc` | 5+: 15.17% | 0: 23.72% | Moderate, monotonic |
| `credit_age_years` | 20–30: 17.85% | 3–5: 23.13% | Weak |
| `open_acc` | 0–4: 17.99% | 20+: 22.24% | Weak |
| `total_acc` | 30–39: 18.62% | < 10: 21.35% | Weak |
| `pub_rec` | 0: 19.32% | 2+: 23.26% | Weak |
| `pub_rec_bankruptcies` | 0: 19.50% | 2+: 23.14% | Weak |
| `revol_bal` | 40k+: 17.77% | 10k–20k: 20.15% | None |

- **Revolving utilisation** is the most useful credit-history feature: borrowers using more of
  their credit limit default more, up to 30% for those above their limit.
- **Mortgage accounts** reduce risk, matching the home-ownership finding.
- Every borrower has at least 3 years of credit history; the shortest band is 3–5 years.

**Is a missing value a signal?**

| Column | Missing | Default when missing | Lift | Years with missing values |
|---|---|---|---|---|
| `emp_length` | 18,301 | 27.53% | 1.40 | 2010 – 2016 |
| `emp_title` | 22,927 | 25.92% | 1.32 | 2007 – 2016 |
| `mort_acc` | 37,795 | 14.68% | 0.75 | **2007 – 2012 only** |
| `revol_util` | 276 | 22.83% | 1.16 | 2008 – 2016 |
| `pub_rec_bankruptcies` | 535 | 16.26% | 0.83 | **2007 – 2009 only** |
| `title` | 1,755 | 18.75% | 0.96 | 2010 – 2016 |

- Missing **employment** information is a genuine risk signal, found in every year.
- Missing `mort_acc` and `pub_rec_bankruptcies` reflect **when the field was collected**, not the
  borrower. They only occur in early years, whose loans are mature and default less, so their low
  default rate is a cohort effect.

**Decisions.**
- Add a utilisation band attribute (`0–20%` … `80–100%`, `> 100%`).
- Keep `mort_acc` NULL as `Unknown`; do not fill with 0, and do not read its low default rate as
  a borrower trait.
- Keep the weak features in the fact table for completeness, but leave them out of headline
  report visuals.

## 6. Outliers

Query: `06_outlier_flags.sql`

| Rule | Flagged loans | Default when flagged | Default otherwise |
|---|---|---|---|
| `revol_util` > 100% | 1,167 | **30.33%** | 19.58% |
| `annual_inc` > 1M | 65 | 12.31% | 19.61% |
| `pub_rec` > 10 | 23 | 43.48% | 19.61% |
| `annual_inc` < 5k | 15 | 40.00% | 19.61% |
| `loan_amnt` < 1k | 10 | 0.00% | 19.61% |
| `dti` > 100 (excl. 9999) | 7 | 0.00% | 19.61% |

- Only `revol_util > 100%` is large enough to trust, and it is a real risk signal, not noise.
  It belongs in the top utilisation band rather than being excluded.
- The other rules cover 120 loans in total, too few for their default rates to mean anything.

**Decision.** Flag, don't remove. Every loan stays in `fact_loans` so totals reconcile to the
source; the rules are recorded in `data_quality_results`.

## 7. Geography

Queries: `07_geography.sql`, `07_state_spread.sql`

| ZIP | Loans | Default rate |
|---|---|---|
| 86630, 93700, 11650 | ~11,000 each | **100.00%** |
| 48052, 70466, 30723, 22690 | ~56,000 each | 19.4% – 20.0% |
| 29597, 00813, 05113 | ~45,500 each | **0.00%** |

- The address field is synthetic: 10 ZIP codes for 396k loans, with states unrelated to ZIP.
- **ZIP was generated from the outcome.** Three ZIPs contain only charged-off loans and three only
  fully paid loans. Using ZIP in analysis or a model would be target leakage.
- State shows no real variation: across 54 states, default ranges only from 18.1% to 20.8%.

**Decision.** Exclude `address`, ZIP and state from the warehouse and the report.

## 8. Redundancy

Queries: `08_feature_pairs.sql`, `08_default_correlation.sql`

| Pair | Correlation | Meaning |
|---|---|---|
| `int_rate` ~ `sub_grade` | 0.974 | Rate is set from sub-grade; nearly the same information |
| `loan_amnt` ~ `installment` | 0.954 | Installment is calculated from amount, rate and term |
| `pub_rec` ~ `pub_rec_bankruptcies` | 0.699 | Bankruptcies are a subset of public records |
| `open_acc` ~ `total_acc` | 0.681 | Open accounts are a subset of all accounts |
| `int_rate` ~ `term_months` | 0.435 | Longer loans are priced higher |

Correlation of each numeric feature with default (absolute value, strongest first): sub-grade
0.263, interest rate 0.248, term 0.173, DTI 0.126, revolving utilisation 0.082, mortgage
accounts −0.073, loan amount 0.060, income −0.053. Everything else is below 0.05.

- `sub_grade` and `int_rate` carry the same signal. Keep both, since one is LendingClub's risk
  rating and the other its price, but don't present them as independent drivers.
- `installment` adds nothing beyond amount, rate and term, and for ~1,550 early loans it reflects
  a **partially funded** amount rather than `loan_amnt` (see the consistency check in the data
  dictionary). Keep it as a measure, but don't use it for analysis.

**Decision.** Drop from the warehouse: `address`, `title`, `emp_title`. Keep `installment` as a
reference measure only.

## Staging decisions

| Area | Decision |
|---|---|
| Cohort | Add `is_mature_cohort` (issue date + term ≤ Dec 2016) |
| Target | `is_default = loan_status = 'Charged Off'` |
| Grade | `dim_grade` at sub-grade level, with grade as the parent |
| Interest rate | Band attribute `< 8%` … `23%+`; flag `int_rate = 6.00` (70 loans) |
| Income | `dim_income_band`: `< 40k`, `40k–60k`, `60k–80k`, `80k–100k`, `100k–150k`, `150k+`; flag `< 5k`, `> 1M` |
| DTI | `dim_dti_band`: `0–10`, `10–20`, `20–30`, `30+`, `Unknown`; 9999 → NULL |
| Utilisation | Band attribute `0–20%` … `80–100%`, `> 100%`, `Unknown` |
| Home ownership | `MORTGAGE`, `RENT`, `OWN`, `OTHER` |
| Employment length | Years 0–10, NULL → `Unknown` (kept: signal) |
| Purpose | All 14 values with readable labels |
| Term | `36` / `60`; use as a report-wide slicer |
| Outliers | Flag in `data_quality_results`; never remove |
| Dropped columns | `address` (leakage), `title`, `emp_title` |
| `installment` | Keep as a reference measure; partially-funded early loans noted |

## Caveats

- The file holds only finished loans, so default rates for loans issued after 2013 are biased.
  Use the mature cohort for trends.
- `loan_amnt` is the amount applied for; some early loans were partly funded, and the funded
  amount is not in this file.
- All findings are single-feature comparisons. Grade, rate, term and purpose overlap, so their
  effects are not additive.
