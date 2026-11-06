-- EDA 7b: how much does default rate vary by state (states with >= 1,000 loans)?
with base as (
    select
        regexp_extract(address, ' ([A-Z]{2}) \d{5}$', 1)   as state,
        loan_status = 'Charged Off'                        as is_default
    from raw.loans
),
by_state as (
    select state, count(*) as n_loans, avg(is_default::int) as rate
    from base
    group by state
    having count(*) >= 1000
)
select
    count(*)                         as states,
    min(n_loans)                     as min_loans,
    max(n_loans)                     as max_loans,
    round(100.0 * min(rate), 2)      as min_default_pct,
    round(100.0 * median(rate), 2)   as median_default_pct,
    round(100.0 * max(rate), 2)      as max_default_pct
from by_state;
