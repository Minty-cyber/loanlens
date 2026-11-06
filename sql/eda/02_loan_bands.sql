-- EDA 2c: default rate by interest-rate band and loan-amount band
with base as (
    select
        cast(int_rate as double)         as int_rate,
        cast(loan_amnt as double)        as loan_amnt,
        loan_status = 'Charged Off'      as is_default
    from raw.loans
),
buckets as (
    select
        'int_rate' as feature,
        case
            when int_rate < 8  then '< 8%'
            when int_rate < 11 then '8-11%'
            when int_rate < 14 then '11-14%'
            when int_rate < 17 then '14-17%'
            when int_rate < 20 then '17-20%'
            when int_rate < 23 then '20-23%'
            else '23%+'
        end        as bucket,
        int_rate   as sort_value,
        is_default
    from base
    union all
    select
        'loan_amnt',
        case
            when loan_amnt < 5000  then '< 5k'
            when loan_amnt < 10000 then '5k-10k'
            when loan_amnt < 15000 then '10k-15k'
            when loan_amnt < 20000 then '15k-20k'
            when loan_amnt < 25000 then '20k-25k'
            when loan_amnt < 30000 then '25k-30k'
            else '30k+'
        end,
        loan_amnt,
        is_default
    from base
)
select
    feature,
    bucket,
    count(*)                                                                    as n_loans,
    round(100.0 * count(*) / sum(count(*)) over (partition by feature), 1)      as pct_loans,
    round(100.0 * avg(is_default::int), 2)                                      as default_rate_pct,
    round(avg(is_default::int) / (select avg(is_default::int) from base), 2)    as lift
from buckets
group by feature, bucket
order by feature, min(sort_value);
