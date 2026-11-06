-- EDA 3a: default rate by income band and debt-to-income band
with base as (
    select
        cast(annual_inc as double)               as annual_inc,
        nullif(cast(dti as double), 9999)        as dti,          -- 9999 is a placeholder
        loan_status = 'Charged Off'              as is_default
    from raw.loans
),
buckets as (
    select
        'annual_inc' as feature,
        case
            when annual_inc < 5000   then '< 5k (flag)'
            when annual_inc < 40000  then '5k-40k'
            when annual_inc < 60000  then '40k-60k'
            when annual_inc < 80000  then '60k-80k'
            when annual_inc < 100000 then '80k-100k'
            when annual_inc < 150000 then '100k-150k'
            when annual_inc <= 1000000 then '150k-1M'
            else '> 1M (flag)'
        end          as bucket,
        annual_inc   as sort_value,
        is_default
    from base
    union all
    select
        'dti',
        case
            when dti is null then 'NULL (9999 placeholder)'
            when dti < 10  then '0-10'
            when dti < 20  then '10-20'
            when dti < 30  then '20-30'
            when dti < 40  then '30-40'
            else '40+'
        end,
        dti,
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
