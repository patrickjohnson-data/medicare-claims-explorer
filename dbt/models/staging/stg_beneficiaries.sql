-- One row per member per year (2008 and 2009).
-- Limited to the members covered by Carrier file 1A (see PLAN.md).

select
    desynpuf_id                                         as member_id,
    cast(regexp_extract(_source_file, '\d{4}') as int)  as coverage_year,
    cast(strptime(bene_birth_dt, '%Y%m%d') as date)  as birth_date,
    cast(strptime(bene_death_dt, '%Y%m%d') as date)  as death_date,

    case bene_sex_ident_cd when '1' then 'Male' when '2' then 'Female' end as sex,
    case bene_race_cd
        when '1' then 'White'
        when '2' then 'Black'
        when '3' then 'Other'
        when '5' then 'Hispanic'
    end                                                 as race,
    sp_state_code                                       as state_code,
    bene_county_cd                                      as county_code,

    -- Chronic conditions: 1 = yes, 2 = no. ESRD: 'Y' = yes, '0' = no.
    bene_esrd_ind = 'Y'                                 as has_esrd,
    sp_alzhdmta   = '1'                                 as has_alzheimers,
    sp_chf        = '1'                                 as has_heart_failure,
    sp_chrnkidn   = '1'                                 as has_kidney_disease,
    sp_cncr       = '1'                                 as has_cancer,
    sp_copd       = '1'                                 as has_copd,
    sp_depressn   = '1'                                 as has_depression,
    sp_diabetes   = '1'                                 as has_diabetes,
    sp_ischmcht   = '1'                                 as has_ischemic_heart_disease,
    sp_osteoprs   = '1'                                 as has_osteoporosis,
    sp_ra_oa      = '1'                                 as has_arthritis,
    sp_strketia   = '1'                                 as has_stroke

from {{ source('raw', 'beneficiary_summary') }}
where desynpuf_id <= '{{ var("max_member_id") }}'
