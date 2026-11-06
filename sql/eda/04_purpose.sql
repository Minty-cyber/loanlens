-- EDA 4: volume, default rate and loan profile by purpose
with base as (
    select
        purpose,
        trim(term)                       as term,
        cast(loan_amnt as double)        as loan_amnt,
        cast(int_rate as double)         as int_rate,
        loan_status = 'Charged Off'      as is_default
    from raw.loans
)
select
    purpose,
    count(*)                                                                    as n_loans,
    round(100.0 * count(*) / sum(count(*)) over (), 2)                          as pct_loans,
    round(100.0 * avg(is_default::int), 2)                                      as default_rate_pct,
    round(avg(is_default::int) / (select avg(is_default::int) from base), 2)    as lift,
    round(avg(loan_amnt), 0)                                                    as avg_loan_amnt,
    round(avg(int_rate), 2)                                                     as avg_rate,
    round(100.0 * count(*) filter (where term = '60 months') / count(*), 1)     as pct_60_month
from base
group by purpose
order by n_loans desc;
