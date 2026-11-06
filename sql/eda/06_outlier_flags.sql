-- EDA 6: do loans flagged as outliers default differently?
with base as (
    select
        cast(annual_inc as double)               as annual_inc,
        cast(dti as double)                      as dti,
        cast(revol_util as double)               as revol_util,
        cast(pub_rec as double)                  as pub_rec,
        cast(loan_amnt as double)                as loan_amnt,
        loan_status = 'Charged Off'              as is_default
    from raw.loans
),
buckets as (
    select 'annual_inc < 5k' as rule,                 annual_inc < 5000             as flagged, is_default from base
    union all
    select 'annual_inc > 1M',                         annual_inc > 1000000,         is_default from base
    union all
    select 'dti > 100 (excl. 9999)',                  dti > 100 and dti <> 9999,    is_default from base
    union all
    select 'revol_util > 100%',                       revol_util > 100,             is_default from base
    union all
    select 'pub_rec > 10',                            pub_rec > 10,                 is_default from base
    union all
    select 'loan_amnt < 1k',                          loan_amnt < 1000,             is_default from base
)
select
    rule,
    count(*) filter (where flagged)                                             as flagged_loans,
    round(100.0 * avg(is_default::int) filter (where flagged), 2)               as flagged_default_pct,
    round(100.0 * avg(is_default::int) filter (where not flagged or flagged is null), 2)
                                                                                as other_default_pct
from buckets
group by rule
order by flagged_loans desc;
