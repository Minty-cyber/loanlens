-- EDA 7a: default rate by ZIP code extracted from the (synthetic) address
with base as (
    select
        regexp_extract(address, '(\d{5})$', 1)   as zip,
        loan_status = 'Charged Off'              as is_default
    from raw.loans
)
select
    zip,
    count(*)                                                                    as n_loans,
    round(100.0 * count(*) / sum(count(*)) over (), 1)                          as pct_loans,
    round(100.0 * avg(is_default::int), 2)                                      as default_rate_pct,
    round(avg(is_default::int) / (select avg(is_default::int) from base), 2)    as lift
from base
group by zip
order by default_rate_pct desc;
