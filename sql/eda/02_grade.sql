-- EDA 2a: default rate, term mix and interest rate by grade
with base as (
    select
        grade,
        trim(term)                       as term,
        cast(int_rate as double)         as int_rate,
        loan_status = 'Charged Off'      as is_default
    from raw.loans
)
select
    grade,
    count(*)                                                                    as n_loans,
    round(100.0 * count(*) / sum(count(*)) over (), 1)                          as pct_loans,
    round(100.0 * avg(is_default::int), 2)                                      as default_rate_pct,
    round(avg(is_default::int) / (select avg(is_default::int) from base), 2)    as lift,
    round(100.0 * avg(is_default::int) filter (where term = '36 months'), 2)    as default_rate_36m,
    round(100.0 * avg(is_default::int) filter (where term = '60 months'), 2)    as default_rate_60m,
    round(100.0 * count(*) filter (where term = '60 months') / count(*), 1)     as pct_60_month,
    min(int_rate)                                                               as min_rate,
    round(avg(int_rate), 2)                                                     as avg_rate,
    max(int_rate)                                                               as max_rate
from base
group by grade
order by grade;
