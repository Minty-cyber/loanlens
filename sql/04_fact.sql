-- Mart fact table. One row per loan

create or replace table mart.fact_loans as

with loans as (
    select * from stg.valid_loans
),

dates as (
    select date_key, month_start from mart.dim_date
),

grades as (
    select grade_key, credit_sub_grade from mart.dim_grade
),

purposes as (
    select purpose_key, purpose_name from mart.dim_purpose
),

home_ownerships as (
    select home_ownership_key, home_ownership_name from mart.dim_home_ownership
),

verifications as (
    select verification_status_key, verification_name from mart.dim_verification
),

dti_bands as (
    select dti_band_key, min_value, max_value from mart.dim_dti_band
),

income_bands as (
    select income_band_key, min_value, max_value from mart.dim_income_band
),

joined as (
    select
        loans.*,
        dates.date_key,
        grades.grade_key,
        purposes.purpose_key,
        home_ownerships.home_ownership_key,
        verifications.verification_status_key,
        coalesce(dti_bands.dti_band_key, 5)                                 as dti_band_key,
        coalesce(income_bands.income_band_key, 7)                           as income_band_key
    from loans
    left join dates
        on dates.month_start = loans.issue_date
    left join grades
        on grades.credit_sub_grade = loans.credit_sub_grade
    left join purposes
        on purposes.purpose_name = loans.loan_purpose
    left join home_ownerships
        on home_ownerships.home_ownership_name = loans.home_ownership
    left join verifications
        on verifications.verification_name = loans.income_verification_status
    left join dti_bands
        on loans.debt_to_income_pct >= dti_bands.min_value
       and (loans.debt_to_income_pct < dti_bands.max_value or dti_bands.max_value is null)
    left join income_bands
        on loans.annual_income >= income_bands.min_value
       and (loans.annual_income < income_bands.max_value or income_bands.max_value is null)
),


final as (
    select
        loan_id,
        -- dimension keys
        date_key,
        grade_key,
        purpose_key,
        term_months                         as term_key,
        home_ownership_key,
        verification_status_key,
        dti_band_key,
        income_band_key,
        -- measures and attributes
        requested_amount,
        interest_rate_pct,
        monthly_installment,
        annual_income,
        debt_to_income_pct,
        revolving_utilization_pct,
        revolving_balance,
        open_credit_lines,
        total_credit_lines,
        derogatory_public_records,
        bankruptcies,
        mortgage_accounts,
        employment_length_years,
        credit_history_months,
        application_type,
        listing_type,
        loan_status,
        cast(is_default as integer)         as default_flag,   -- 1 = Charged Off, 0 = Fully Paid
        is_mature_cohort,
        -- data quality flags
        is_rate_anomaly,
        is_income_outlier,
        is_dti_outlier,
        is_over_credit_limit,
        is_partially_funded
    from joined
)

select * from final;
