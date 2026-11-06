-- Mature cohort: loans whose full term ended by Dec 2016 (latest issue month)
with loans as (
    select
        strptime(issue_d, '%b-%Y')                       as issue_date,
        cast(regexp_extract(term, '\d+') as integer)     as term_months,
        loan_status = 'Charged Off'                      as is_default
    from raw.loans
)
select
    issue_date + to_months(term_months) <= date '2016-12-01'   as is_mature_cohort,
    count(*)                                                    as loans,
    round(100.0 * count(*) / sum(count(*)) over (), 1)          as pct_of_loans,
    round(100.0 * avg(is_default::int), 2)                      as default_rate_pct
from loans
group by all
order by is_mature_cohort desc;
