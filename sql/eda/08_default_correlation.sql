-- EDA 8b: correlation of each numeric feature with default (point-biserial)
with base as (
    select
        (loan_status = 'Charged Off')::int       as is_default,
        cast(int_rate as double)                 as int_rate,
        (ascii(sub_grade[1]) - ascii('A')) * 5 + cast(sub_grade[2] as integer)
                                                 as sub_grade_rank,
        cast(regexp_extract(term, '\d+') as integer) as term_months,
        cast(loan_amnt as double)                as loan_amnt,
        cast(installment as double)              as installment,
        cast(annual_inc as double)               as annual_inc,
        nullif(cast(dti as double), 9999)        as dti,
        cast(revol_util as double)               as revol_util,
        cast(revol_bal as double)                as revol_bal,
        cast(open_acc as double)                 as open_acc,
        cast(total_acc as double)                as total_acc,
        cast(pub_rec as double)                  as pub_rec,
        cast(pub_rec_bankruptcies as double)     as pub_rec_bankruptcies,
        cast(mort_acc as double)                 as mort_acc,
        date_diff('month', strptime(earliest_cr_line, '%b-%Y'), strptime(issue_d, '%b-%Y'))
                                                 as credit_age_months
    from raw.loans
),
corrs as (
    select
        round(corr(int_rate, is_default), 3)             as int_rate,
        round(corr(sub_grade_rank, is_default), 3)       as sub_grade_rank,
        round(corr(term_months, is_default), 3)          as term_months,
        round(corr(loan_amnt, is_default), 3)            as loan_amnt,
        round(corr(installment, is_default), 3)          as installment,
        round(corr(annual_inc, is_default), 3)           as annual_inc,
        round(corr(dti, is_default), 3)                  as dti,
        round(corr(revol_util, is_default), 3)           as revol_util,
        round(corr(revol_bal, is_default), 3)            as revol_bal,
        round(corr(open_acc, is_default), 3)             as open_acc,
        round(corr(total_acc, is_default), 3)            as total_acc,
        round(corr(pub_rec, is_default), 3)              as pub_rec,
        round(corr(pub_rec_bankruptcies, is_default), 3) as pub_rec_bankruptcies,
        round(corr(mort_acc, is_default), 3)             as mort_acc,
        round(corr(credit_age_months, is_default), 3)    as credit_age_months
    from base
),
long as (
    unpivot corrs
    on columns(*)
    into name feature value correlation_with_default
)
select feature, correlation_with_default
from long
order by abs(correlation_with_default) desc;
