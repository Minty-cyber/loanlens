-- Outlier check: how many rows break each plausibility rule
with total as (
    select count(*) as n from raw.loans
),

flags as (
    select
        count(*) filter (where cast(dti as double) = 9999)                as "dti = 9999 (placeholder)",
        count(*) filter (where cast(dti as double) > 100)                 as "dti > 100",
        count(*) filter (where cast(dti as double) = 0)                   as "dti = 0",
        count(*) filter (where cast(annual_inc as double) = 0)            as "annual_inc = 0",
        count(*) filter (where cast(annual_inc as double) < 5000)         as "annual_inc < 5,000",
        count(*) filter (where cast(annual_inc as double) > 1000000)      as "annual_inc > 1M",
        count(*) filter (where cast(revol_util as double) > 100)          as "revol_util > 100%",
        count(*) filter (where cast(revol_util as double) > 150)          as "revol_util > 150%",
        count(*) filter (where cast(loan_amnt as double) < 1000)          as "loan_amnt < 1,000",
        count(*) filter (where cast(int_rate as double) not between 5 and 31)
                                                                          as "int_rate outside 5-31%",
        count(*) filter (where cast(open_acc as double) = 0)              as "open_acc = 0",
        count(*) filter (where cast(pub_rec as double) > 10)              as "pub_rec > 10",
        count(*) filter (where least(
                cast(loan_amnt as double), cast(int_rate as double), cast(installment as double),
                cast(annual_inc as double), cast(dti as double), cast(revol_bal as double),
                cast(revol_util as double), cast(open_acc as double), cast(total_acc as double),
                cast(pub_rec as double), cast(mort_acc as double),
                cast(pub_rec_bankruptcies as double)) < 0)                as "any negative value"
    from raw.loans
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
