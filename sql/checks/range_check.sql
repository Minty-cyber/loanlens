-- Range check distribution of every numeric column in raw.loans
with long as (
    unpivot raw.loans
    on loan_amnt, int_rate, installment, annual_inc, dti, revol_bal, revol_util,
       open_acc, total_acc, pub_rec, mort_acc, pub_rec_bankruptcies
    into name column_name value val
),

nums as (
    select column_name, cast(val as double) as x   
    from long
)

select
    column_name,
    count(*)                    as n,
    min(x)                      as min,
    quantile_cont(x, 0.01)      as p01,
    median(x)                   as p50,
    round(avg(x), 2)            as mean,
    quantile_cont(x, 0.99)      as p99,
    max(x)                      as max
from nums
group by column_name
order by column_name;
