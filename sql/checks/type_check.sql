-- automated type check for the key columns in the dataset
with long as (
    unpivot raw.loans
    on columns(* exclude(source_row))
    into name column_name value val
),

rules as (
    select  * from (values
        ('loan_amnt',       'DECIMAL'),
        ('int_rate',        'DECIMAL'),
        ('installment',        'DECIMAL'),
        ('annual_inc',        'DECIMAL'),
        ('dti',        'DECIMAL'),
        ('revol_bal',            'DECIMAL'),
        ('revol_util',           'DECIMAL'),
        ('open_acc',             'INTEGER'),
        ('total_acc',            'INTEGER'),
        ('pub_rec',              'INTEGER'),
        ('mort_acc',             'INTEGER'),
        ('pub_rec_bankruptcies', 'INTEGER'),
        ('issue_d',              'DATE'),
        ('earliest_cr_line',     'DATE'),
        ('term',                 'TERM'),
        ('emp_length',           'EMP_LENGTH')
    ) as t(column_name, target_type)

)
select 
    r.column_name,
    r.target_type,
    count(*)                    as values_checked,
    count(*) filter (where
        case r.target_type
            when 'DECIMAL'          then try_cast(l.val as double) is null
            when 'INTEGER'          then try_cast(l.val as double) is null or try_cast(l.val as double) <> floor(try_cast(l.val as double))
            when 'DATE'       then try_strptime(l.val, '%b-%Y') is null
            when 'TERM'       then regexp_extract(trim(l.val), '^(\d+) months$', 1) = ''
            when 'EMP_LENGTH' then not regexp_matches(l.val, '^(< 1 year|1 year|[2-9] years|10\+ years)$')
        end

    ) as failed
from rules r
join long l using (column_name)
group by all
order by failed desc, r.column_name;