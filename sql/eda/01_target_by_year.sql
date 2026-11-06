-- Default rate by issue year, overall and per term
with loans as (
    select
        year(strptime(issue_d, '%b-%Y'))                                                as issue_year,
        trim(term)                                                                      as term,
        loan_status = 'Charged Off'                                                     as is_default,
        cast(loan_amnt as double)                                                       as loan_amnt
    from raw.loans
)
select
    issue_year,
    count(*)                                                                            as loans,
    round(100.0 * count(*) filter (where term = '60 months') / count(*), 1)             as pct_60_month,
    round(100.0 * avg(is_default::int), 2)                                              as default_rate_pct,
    round(100.0 * avg(is_default::int) filter (where term = '36 months'), 2)            as default_rate_36m,
    round(100.0 * avg(is_default::int) filter (where term = '60 months'), 2)            as default_rate_60m,
    round(sum(loan_amnt) / 1e6, 1)                                                      as funded_musd
from loans
group by issue_year
order by issue_year;
