-- Load the raw Kaggle dataset as-is (all text, no cleaning)
create schema if not exists raw;

create or replace table raw.loans as
select
    row_number() over () as source_row,
    *
from read_csv(
    '{{ RAW_CSV }}',
    header = true,
    all_varchar = true
);
