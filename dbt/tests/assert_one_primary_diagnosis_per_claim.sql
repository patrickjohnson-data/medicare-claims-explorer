-- Each claim can have at most one primary diagnosis.
-- Otherwise the claim would be counted twice in cost_by_diagnosis.

select
    claim_id,
    count(*) as primary_count
from {{ ref('fct_claim_diagnoses') }}
where is_primary
group by claim_id
having count(*) > 1
