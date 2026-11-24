-- One row per claim per diagnosis code, with the ICD-9 description.
-- About 3% of codes have no match in the CMS list (mostly synthetic-data
-- quirks such as shortened codes); those get 'Unknown code'.

select
    d.claim_type,
    d.claim_id,
    d.dx_code,
    coalesce(icd.long_description, 'Unknown code')     as dx_description,
    d.is_primary
from {{ ref('int_claim_diagnoses') }} as d
left join {{ ref('icd9_diagnoses') }} as icd
    on icd.icd9_code = d.dx_code
