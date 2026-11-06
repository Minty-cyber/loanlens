-- EDA 3b: default rate by borrower / application category
with base as (
    select
        emp_length,
        case
            when emp_length = '< 1 year'   then 0
            when emp_length = '10+ years'  then 10
            else cast(regexp_extract(emp_length, '\d+') as integer)
        end                                  as emp_years,
        home_ownership,
        verification_status,
        application_type,
        initial_list_status,
        loan_status = 'Charged Off'          as is_default
    from raw.loans
),
buckets as (
    select 'emp_length' as feature, coalesce(emp_length, 'NULL') as bucket,
           emp_years as sort_value, is_default from base
    union all
    select 'home_ownership',      home_ownership,      null, is_default from base
    union all
    select 'verification_status', verification_status, null, is_default from base
    union all
    select 'application_type',    application_type,    null, is_default from base
    union all
    select 'initial_list_status', initial_list_status, null, is_default from base
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
order by feature, min(sort_value), count(*) desc;
