-- One row per claim, with its month and primary diagnosis.

select
    c.claim_type,
    c.claim_id,
    c.member_id,
    c.provider_id,
    c.claim_start_date,
    c.claim_end_date,
    cast(date_trunc('month', c.claim_start_date) as date)  as claim_month,
    dx.dx_code                                          as primary_dx_code,
    c.payment_amount
from {{ ref('int_claims') }} as c
left join {{ ref('int_claim_diagnoses') }} as dx
    on  dx.claim_id = c.claim_id
    and dx.is_primary
