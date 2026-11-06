-- EDA 5b: is a missing value itself a signal? Default rate when null vs present
with base as (
    select *, loan_status = 'Charged Off' as is_default,
           year(strptime(issue_d, '%b-%Y')) as issue_year
    from raw.loans
),
buckets as (
    select 'mort_acc' as feature, mort_acc is null as is_missing, issue_year, is_default from base
    union all
    select 'emp_length',           emp_length is null,           issue_year, is_default from base
    union all
    select 'emp_title',            emp_title is null,            issue_year, is_default from base
    union all
    select 'title',                title is null,                issue_year, is_default from base
    union all
    select 'pub_rec_bankruptcies', pub_rec_bankruptcies is null, issue_year, is_default from base
    union all
    select 'revol_util',           revol_util is null,           issue_year, is_default from base
)
select
    feature,
    is_missing,
    count(*)                                                                    as n_loans,
    round(100.0 * avg(is_default::int), 2)                                      as default_rate_pct,
    round(avg(is_default::int) / (select avg(is_default::int) from base), 2)    as lift,
    min(issue_year)                                                             as first_year,
    max(issue_year)                                                             as last_year,
    median(issue_year)                                                          as median_year
from buckets
group by feature, is_missing
order by feature, is_missing;
