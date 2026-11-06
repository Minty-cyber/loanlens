-- EDA 2b: default rate and interest rate by sub-grade (A1 .. G5)
with base as (
    select
        sub_grade,
        cast(int_rate as double)         as int_rate,
        loan_status = 'Charged Off'      as is_default
    from raw.loans
)
select
    sub_grade,
    count(*)                                                                    as n_loans,
    round(100.0 * count(*) / sum(count(*)) over (), 2)                          as pct_loans,
    round(100.0 * avg(is_default::int), 2)                                      as default_rate_pct,
    round(avg(is_default::int) / (select avg(is_default::int) from base), 2)    as lift,
    round(avg(int_rate), 2)                                                     as avg_rate
from base
group by sub_grade
order by sub_grade;
