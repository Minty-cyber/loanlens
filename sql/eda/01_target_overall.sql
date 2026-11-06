select 
    coalesce(trim(term), 'ALL')                                 as term,
    count(*)                                                    as loans,
    count(*) filter  (where loan_status = 'Charged Off')        as charged_off,
    round(100.0 * count(*) filter (where loan_status = 'Charged Off') / count(*), 2) as default_rate_pct,
    round(sum(cast(loan_amnt as double)) / 1e6, 1)              as funded_musd
from raw.loans
group by rollup (trim(term))
order by term;