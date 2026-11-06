-- Consistency check: rows where columns contradict each other
with total as (
    select count(*) as n from raw.loans
),

typed as (
    select
        strptime(issue_d, '%b-%Y')                        as issue_date,
        strptime(earliest_cr_line, '%b-%Y')               as first_credit_date,
        cast(regexp_extract(term, '\d+') as integer)      as term_months,
        cast(loan_amnt as double)                         as loan_amnt,
        cast(int_rate as double) / 100 / 12               as monthly_rate,
        cast(installment as double)                       as installment,
        cast(open_acc as double)                          as open_acc,
        cast(total_acc as double)                         as total_acc,
        cast(pub_rec as double)                           as pub_rec,
        cast(pub_rec_bankruptcies as double)              as pub_rec_bankruptcies,
        cast(revol_bal as double)                         as revol_bal,
        cast(revol_util as double)                        as revol_util
    from raw.loans
),

calc as (
    select
        *,
        -- standard amortised payment: P * r / (1 - (1 + r)^-n)
        loan_amnt * monthly_rate / (1 - power(1 + monthly_rate, -term_months)) as expected_installment,
        date_diff('month', first_credit_date, issue_date)                      as credit_age_months
    from typed
),

flags as (
    select
        count(*) filter (where first_credit_date >= issue_date)
            as "first credit line on/after issue date",
        count(*) filter (where credit_age_months between 0 and 11)
            as "credit history < 1 year at issue",
        count(*) filter (where abs(installment - expected_installment) > 1)
            as "installment off formula by > $1",
        count(*) filter (where abs(installment - expected_installment) / expected_installment > 0.05)
            as "installment off formula by > 5%",
        count(*) filter (where open_acc > total_acc)
            as "open_acc > total_acc",
        count(*) filter (where pub_rec_bankruptcies > pub_rec)
            as "bankruptcies > public records",
        count(*) filter (where revol_bal > 0 and revol_util = 0)
            as "revol_bal > 0 but revol_util = 0",
        count(*) filter (where revol_bal = 0 and revol_util > 0)
            as "revol_bal = 0 but revol_util > 0",
        count(*) filter (where installment * term_months < loan_amnt)
            as "total repayments < amount borrowed"
    from calc
),

long as (
    unpivot flags
    on columns(*)
    into name rule value n_rows
)

select
    rule,
    n_rows,
    round(100.0 * n_rows / (select n from total), 3) as pct
from long
order by n_rows desc;
