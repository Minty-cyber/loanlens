-- EDA 5a: default rate by credit-history bands
with base as (
    select
        date_diff('month', strptime(earliest_cr_line, '%b-%Y'), strptime(issue_d, '%b-%Y')) / 12.0
                                                 as credit_age_years,
        cast(revol_util as double)               as revol_util,
        cast(revol_bal as double)                as revol_bal,
        cast(open_acc as double)                 as open_acc,
        cast(total_acc as double)                as total_acc,
        cast(pub_rec as double)                  as pub_rec,
        cast(pub_rec_bankruptcies as double)     as pub_rec_bankruptcies,
        cast(mort_acc as double)                 as mort_acc,
        loan_status = 'Charged Off'              as is_default
    from raw.loans
),
buckets as (
    select 'credit_age_years' as feature,
        case
            when credit_age_years < 3  then '< 3'
            when credit_age_years < 5  then '3-5'
            when credit_age_years < 10 then '5-10'
            when credit_age_years < 15 then '10-15'
            when credit_age_years < 20 then '15-20'
            when credit_age_years < 30 then '20-30'
            else '30+'
        end as bucket, credit_age_years as sort_value, is_default
    from base
    union all
    select 'revol_util',
        case
            when revol_util is null then 'NULL'
            when revol_util < 20  then '0-20%'
            when revol_util < 40  then '20-40%'
            when revol_util < 60  then '40-60%'
            when revol_util < 80  then '60-80%'
            when revol_util <= 100 then '80-100%'
            else '> 100% (flag)'
        end, revol_util, is_default
    from base
    union all
    select 'revol_bal',
        case
            when revol_bal < 5000  then '< 5k'
            when revol_bal < 10000 then '5k-10k'
            when revol_bal < 20000 then '10k-20k'
            when revol_bal < 40000 then '20k-40k'
            else '40k+'
        end, revol_bal, is_default
    from base
    union all
    select 'open_acc',
        case
            when open_acc < 5  then '0-4'
            when open_acc < 10 then '5-9'
            when open_acc < 15 then '10-14'
            when open_acc < 20 then '15-19'
            else '20+'
        end, open_acc, is_default
    from base
    union all
    select 'total_acc',
        case
            when total_acc < 10 then '< 10'
            when total_acc < 20 then '10-19'
            when total_acc < 30 then '20-29'
            when total_acc < 40 then '30-39'
            else '40+'
        end, total_acc, is_default
    from base
    union all
    select 'pub_rec',
        case when pub_rec = 0 then '0' when pub_rec = 1 then '1' else '2+' end,
        pub_rec, is_default
    from base
    union all
    select 'pub_rec_bankruptcies',
        case
            when pub_rec_bankruptcies is null then 'NULL'
            when pub_rec_bankruptcies = 0 then '0'
            when pub_rec_bankruptcies = 1 then '1'
            else '2+'
        end, pub_rec_bankruptcies, is_default
    from base
    union all
    select 'mort_acc',
        case
            when mort_acc is null then 'NULL'
            when mort_acc = 0 then '0'
            when mort_acc = 1 then '1'
            when mort_acc = 2 then '2'
            when mort_acc < 5 then '3-4'
            else '5+'
        end, mort_acc, is_default
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
