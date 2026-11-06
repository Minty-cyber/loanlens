-- Allowed-value check values in category columns that aren't in the expected list
with long as (
    unpivot raw.loans
    on term, grade, sub_grade, home_ownership, verification_status,
       loan_status, purpose, initial_list_status, application_type
    into name column_name value val
),

allowed as (
    select * from (values
        ('term',                '36 months'),
        ('term',                '60 months'),
        ('grade',               'A'), ('grade', 'B'), ('grade', 'C'), ('grade', 'D'),
        ('grade',               'E'), ('grade', 'F'), ('grade', 'G'),
        ('home_ownership',      'MORTGAGE'), ('home_ownership', 'RENT'), ('home_ownership', 'OWN'),
        ('home_ownership',      'OTHER'),    ('home_ownership', 'NONE'), ('home_ownership', 'ANY'),
        ('verification_status', 'Verified'),
        ('verification_status', 'Source Verified'),
        ('verification_status', 'Not Verified'),
        ('loan_status',         'Fully Paid'),
        ('loan_status',         'Charged Off'),
        ('purpose',             'debt_consolidation'), ('purpose', 'credit_card'),
        ('purpose',             'home_improvement'),   ('purpose', 'other'),
        ('purpose',             'major_purchase'),     ('purpose', 'small_business'),
        ('purpose',             'car'),                ('purpose', 'medical'),
        ('purpose',             'moving'),             ('purpose', 'vacation'),
        ('purpose',             'house'),              ('purpose', 'wedding'),
        ('purpose',             'renewable_energy'),   ('purpose', 'educational'),
        ('initial_list_status', 'f'),
        ('initial_list_status', 'w'),
        ('application_type',    'INDIVIDUAL'),
        ('application_type',    'JOINT'),
        ('application_type',    'DIRECT_PAY')
    ) as t(column_name, allowed_value)

    union all

    
    select 'sub_grade', g || n::varchar
    from unnest(['A', 'B', 'C', 'D', 'E', 'F', 'G']) as u(g)
    cross join range(1, 6) as r(n)
),

expected as (
    select column_name, count(*) as expected_values
    from allowed
    group by column_name
)

select
    l.column_name,
    e.expected_values,
    count(distinct trim(l.val))                                  as distinct_values,
    count(*) filter (where a.allowed_value is null)              as unexpected_rows,
    list(distinct l.val) filter (where a.allowed_value is null)  as unexpected_values,
    count(*) filter (where l.val <> trim(l.val))                 as untrimmed_rows
from long l
left join allowed a
       on a.column_name   = l.column_name
      and a.allowed_value = trim(l.val)
join expected e on e.column_name = l.column_name
group by all
order by unexpected_rows desc, l.column_name;
