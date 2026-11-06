-- EDA 8a: correlation between feature pairs that may duplicate each other
with base as (
    select
        cast(loan_amnt as double)                as loan_amnt,
        cast(installment as double)              as installment,
        cast(int_rate as double)                 as int_rate,
        -- sub_grade as an ordered number: A1 = 1 ... G5 = 35
        (ascii(sub_grade[1]) - ascii('A')) * 5 + cast(sub_grade[2] as integer)
                                                 as sub_grade_rank,
        cast(regexp_extract(term, '\d+') as integer) as term_months,
        cast(open_acc as double)                 as open_acc,
        cast(total_acc as double)                as total_acc,
        cast(pub_rec as double)                  as pub_rec,
        cast(pub_rec_bankruptcies as double)     as pub_rec_bankruptcies,
        cast(revol_bal as double)                as revol_bal,
        cast(revol_util as double)               as revol_util,
        cast(annual_inc as double)               as annual_inc,
        cast(mort_acc as double)                 as mort_acc
    from raw.loans
),
pairs as (
    select
        round(corr(int_rate, sub_grade_rank), 3)            as "int_rate ~ sub_grade",
        round(corr(loan_amnt, installment), 3)              as "loan_amnt ~ installment",
        round(corr(open_acc, total_acc), 3)                 as "open_acc ~ total_acc",
        round(corr(pub_rec, pub_rec_bankruptcies), 3)       as "pub_rec ~ pub_rec_bankruptcies",
        round(corr(revol_bal, revol_util), 3)               as "revol_bal ~ revol_util",
        round(corr(loan_amnt, annual_inc), 3)               as "loan_amnt ~ annual_inc",
        round(corr(int_rate, term_months), 3)               as "int_rate ~ term_months",
        round(corr(mort_acc, total_acc), 3)                 as "mort_acc ~ total_acc"
    from base
),
long as (
    unpivot pairs
    on columns(*)
    into name pair value correlation
)
select pair, correlation
from long
order by abs(correlation) desc;
