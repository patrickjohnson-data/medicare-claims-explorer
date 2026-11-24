-- One row per member, using their latest year on file (2009, or 2008 for
-- members who died in 2008).

with ranked as (

    select
        *,
        row_number() over (partition by member_id order by coverage_year desc) as row_num
    from {{ ref('stg_beneficiaries') }}

)

select
    member_id,
    coverage_year                                       as latest_coverage_year,
    birth_date,
    death_date,
    sex,
    race,
    state_code,
    county_code,
    has_esrd,
    has_alzheimers,
    has_heart_failure,
    has_kidney_disease,
    has_cancer,
    has_copd,
    has_depression,
    has_diabetes,
    has_ischemic_heart_disease,
    has_osteoporosis,
    has_arthritis,
    has_stroke
from ranked
where row_num = 1
