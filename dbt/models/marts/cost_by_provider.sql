-- Medicare spending per provider and claim type.
-- Inpatient and outpatient providers are facilities (CMS provider numbers);
-- carrier providers are individual doctors (NPIs). A facility that bills
-- both inpatient and outpatient gets one row for each.

select
    claim_type,
    provider_id,
    count(*)                                            as claim_count,
    count(distinct member_id)                           as member_count,
    sum(payment_amount)                                 as total_payment,
    round(avg(payment_amount), 2)                       as avg_payment_per_claim,
    round(count(*) / count(distinct member_id), 2)      as claims_per_member
from {{ ref('fct_claims') }}
where provider_id is not null
group by claim_type, provider_id
