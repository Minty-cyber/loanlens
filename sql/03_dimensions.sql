-- Mart dimensions

create schema if not exists mart;

-- one row per calendar month
create or replace table mart.dim_date as

with date_spine as (
    select
        cast(date_trunc('month', min(issue_date)) as timestamp)        as start_month,
        cast(date_trunc('month', max(issue_date)) as timestamp)        as end_month
    from stg.valid_loans
),

months as (
    select
        cast(unnest(generate_series(
            start_month, end_month, interval 1 month
        )) as date)                                                     as month_start
    from date_spine
),

final as (
    select
        cast(year(month_start) * 100 + month(month_start) as integer)   as date_key,
        month_start,
        year(month_start)                                               as year,
        quarter(month_start)                                            as quarter,
        month(month_start)                                              as month_number,
        strftime(month_start, '%b')                                     as month_name,
        strftime(month_start, '%Y-%m')                                  as year_month
    from months
)

select * from final;


-- one row per sub-grade
create or replace table mart.dim_grade as

with grades as (
    select distinct credit_sub_grade, credit_grade
    from stg.valid_loans
),

final as (
    select
        row_number() over (order by credit_sub_grade)                   as grade_key,
        credit_sub_grade,
        credit_grade,
        case
            when credit_grade in ('A', 'B') then 'Low'
            when credit_grade in ('C', 'D') then 'Medium'
            else 'High'
        end                                                             as risk_band
    from grades
)

select * from final;


-- dim_purpose
create or replace table mart.dim_purpose as

with purposes as (
    select distinct loan_purpose
    from stg.valid_loans
),

final as (
    select
        row_number() over (order by loan_purpose)                       as purpose_key,
        loan_purpose                                                    as purpose_name
    from purposes
)

select * from final;


-- dim_term the key is the number of months itself
create or replace table mart.dim_term as

with terms as (
    select distinct term_months
    from stg.valid_loans
),

final as (
    select
        term_months                                                     as term_key,
        term_months,
        cast(term_months as varchar) || ' months'                       as term_label
    from terms
)

select * from final;


-- dim_home_ownership
create or replace table mart.dim_home_ownership as

with categories as (
    select distinct home_ownership
    from stg.valid_loans
),

final as (
    select
        row_number() over (order by home_ownership)                     as home_ownership_key,
        home_ownership                                                  as home_ownership_name
    from categories
)

select * from final;


-- dim_verification
create or replace table mart.dim_verification as

with categories as (
    select distinct income_verification_status
    from stg.valid_loans
),

final as (
    select
        row_number() over (order by income_verification_status)         as verification_status_key,
        income_verification_status                                      as verification_name
    from categories
)

select * from final;


-- dim_dti_band
create or replace table mart.dim_dti_band as

with bands as (
    select * from (values
        (1, '0-10',    1, 0,    10),
        (2, '10-20',   2, 10,   20),
        (3, '20-30',   3, 20,   30),
        (4, '30+',     4, 30,   null),
        (5, 'Unknown', 5, null, null)
    ) as t(dti_band_key, dti_band, sort_order, min_value, max_value)
)

select * from bands;


-- dim_income_band
create or replace table mart.dim_income_band as

with bands as (
    select * from (values
        (1, 'Under 40k', 1, 0,      40000),
        (2, '40k-60k',   2, 40000,  60000),
        (3, '60k-80k',   3, 60000,  80000),
        (4, '80k-100k',  4, 80000,  100000),
        (5, '100k-150k', 5, 100000, 150000),
        (6, '150k+',     6, 150000, null),
        (7, 'Unknown',   7, null,   null)
    ) as t(income_band_key, income_band, sort_order, min_value, max_value)
)

select * from bands;
