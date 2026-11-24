-- Hospital stays. One row per claim segment (claim_id + segment).
-- Segment 2 rows continue the same claim: they carry payments but no dates.

select
    clm_id                                      as claim_id,
    cast(segment as int)                        as segment,
    desynpuf_id                                 as member_id,
    cast(strptime(clm_from_dt, '%Y%m%d') as date)  as claim_start_date,
    cast(strptime(clm_thru_dt, '%Y%m%d') as date)  as claim_end_date,
    prvdr_num                                   as provider_id,
    at_physn_npi                                as attending_npi,
    cast(clm_pmt_amt as decimal(12, 2))         as payment_amount,
    cast(clm_utlztn_day_cnt as int)             as hospital_days,
    clm_drg_cd                                  as drg_code,

    -- Diagnosis codes 1-10, kept wide; unpivoted in intermediate.
    icd9_dgns_cd_1                              as dx_code_1,
    icd9_dgns_cd_2                              as dx_code_2,
    icd9_dgns_cd_3                              as dx_code_3,
    icd9_dgns_cd_4                              as dx_code_4,
    icd9_dgns_cd_5                              as dx_code_5,
    icd9_dgns_cd_6                              as dx_code_6,
    icd9_dgns_cd_7                              as dx_code_7,
    icd9_dgns_cd_8                              as dx_code_8,
    icd9_dgns_cd_9                              as dx_code_9,
    icd9_dgns_cd_10                             as dx_code_10

from {{ source('raw', 'inpatient_claims') }}
where desynpuf_id <= '{{ var("max_member_id") }}'
