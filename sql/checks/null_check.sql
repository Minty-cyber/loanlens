-- check for null values and their percentage in the dataset
with total as (
    select count(*) as n from raw.loans
),

long as (
    unpivot raw.loans
    on columns(* exclude (source_row))
    into name column_name value val
)

select  
    column_name,
   (select n from total) - count(*)                                                                 as real_nulls,
    count(*) filter (where trim(val) = '')                                                          as empty_strings,
    count(*) filter (where lower(trim(val)) in ('na', 'n/a', 'null', 'none', 'nan', '-'))           as null_like_text,
    round(100.0 * ((select n from total) - count(*)) / (select n from total), 2)                    as pct_null
from long
group by column_name
order by real_nulls desc, column_name;