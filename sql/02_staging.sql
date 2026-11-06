-- Type, standardise and flag. Rows that cannot be trusted go to stg.rejected_loans with a reason.
-- Nothing is deleted without a record of why.

create schema if not exists stg;

create or replace table stg.loans as

with source as (
    select * from raw.loans
),

typed as (
    select
        source_row                                                              as loan_id,
        try_cast(loan_amnt as double)                                           as requested_amount,
        try_cast(regexp_extract(term, '(\d+)', 1) as integer)                   as term_months,
        try_cast(int_rate as double)                                            as interest_rate_pct,
        try_cast(installment as double)                                         as monthly_installment,
        try_cast(annual_inc as double)                                          as annual_income,
        nullif(try_cast(dti as double), 9999)                                   as debt_to_income_pct,
        try_cast(open_acc as integer)                                           as open_credit_lines,
        try_cast(total_acc as integer)                                          as total_credit_lines,
        try_cast(pub_rec as integer)                                            as derogatory_public_records,
        try_cast(pub_rec_bankruptcies as integer)                               as bankruptcies,
        try_cast(mort_acc as integer)                                           as mortgage_accounts,
        try_cast(revol_bal as double)                                           as revolving_balance,
        try_cast(revol_util as double)                                          as revolving_utilization_pct,
        cast(try_strptime(issue_d, '%b-%Y') as date)                            as issue_date,
        cast(try_strptime(earliest_cr_line, '%b-%Y') as date)                   as first_credit_line_date,
        grade,
        sub_grade,
        emp_length,
        home_ownership,
        verification_status,
        loan_status,
        purpose,
        application_type,
        initial_list_status
    from source
),

standardised as (
    select
        loan_id,
        requested_amount,
        term_months,
        interest_rate_pct,
        monthly_installment,
        annual_income,
        debt_to_income_pct,
        open_credit_lines,
        total_credit_lines,
        derogatory_public_records,
        bankruptcies,
        mortgage_accounts,
        revolving_balance,
        revolving_utilization_pct,
        issue_date,
        first_credit_line_date,
        upper(trim(grade))                                                      as credit_grade,
        upper(trim(sub_grade))                                                  as credit_sub_grade,
        case
            when emp_length is null         then null       
            when emp_length like '10+%'     then 10
            when emp_length like '<%'       then 0
            else try_cast(regexp_extract(emp_length, '(\d+)', 1) as integer)
        end                                                                     as employment_length_years,
        case upper(trim(home_ownership))
            when 'RENT'                     then 'Rent'
            when 'OWN'                      then 'Own'
            when 'MORTGAGE'                 then 'Mortgage'
            else 'Other'                                    
        end                                                                     as home_ownership,
        trim(verification_status)                                               as income_verification_status,
        trim(loan_status)                                                       as loan_status,
        trim(loan_status) = 'Charged Off'                                       as is_default,
        upper(substr(replace(trim(purpose), '_', ' '), 1, 1))
            || substr(replace(trim(purpose), '_', ' '), 2)                      as loan_purpose,
        case upper(trim(application_type))
            when 'INDIVIDUAL'               then 'Individual'
            when 'JOINT'                    then 'Joint'
            when 'DIRECT_PAY'               then 'Direct pay'
        end                                                                     as application_type,
        case lower(trim(initial_list_status))
            when 'w'                        then 'Whole'
            when 'f'                        then 'Fractional'
        end                                                                     as listing_type
    from typed
),

flagged as (
    select
        *,
        date_diff('month', first_credit_line_date, issue_date)                 as credit_history_months,

        issue_date + to_months(term_months) <= date '2016-12-01'                as is_mature_cohort,

        interest_rate_pct = 6.0 and credit_grade <> 'A'                         as is_rate_anomaly,
        annual_income < 5000 or annual_income > 1000000                         as is_income_outlier,
        debt_to_income_pct > 100                                                as is_dti_outlier,
        revolving_utilization_pct > 100                                         as is_over_credit_limit,

        monthly_installment < requested_amount * (interest_rate_pct / 1200)
            / (1 - power(1 + interest_rate_pct / 1200, -term_months)) - 1       as is_partially_funded
    from standardised
)

select * from flagged;


create or replace table stg.rejected_loans as

with loans as (
    select * from stg.loans
),

checked as (
    select
        loan_id,
        case
            when requested_amount is null or requested_amount <= 0                     then 'Invalid requested amount'
            when credit_grade is null or credit_grade not in ('A','B','C','D','E','F','G') then 'Invalid grade'
            when credit_sub_grade is null or left(credit_sub_grade, 1) <> credit_grade then 'Sub-grade does not match grade'
            when term_months is null or term_months not in (36, 60)                    then 'Invalid term'
            when interest_rate_pct is null or interest_rate_pct not between 1 and 40   then 'Interest rate out of range'
            when issue_date is null                                                    then 'Invalid issue date'
            when loan_status is null or loan_status not in ('Fully Paid', 'Charged Off') then 'Unknown loan status'
        end                                                                            as reject_reason
    from loans
)

select loan_id, reject_reason
from checked
where reject_reason is not null;


create or replace table stg.valid_loans as

with loans as (
    select * from stg.loans
),

rejected as (
    select * from stg.rejected_loans
),

valid as (
    select loans.*
    from loans
    left join rejected on rejected.loan_id = loans.loan_id
    where rejected.loan_id is null
)

select * from valid;
