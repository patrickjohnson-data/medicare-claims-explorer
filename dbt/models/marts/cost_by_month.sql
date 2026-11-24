-- Medicare spending per month and claim type.

select
    claim_month,
    claim_type,
    count(*)                                            as claim_count,
    count(distinct member_id)                           as member_count,
    sum(payment_amount)                                 as total_payment
from {{ ref('fct_claims') }}
group by claim_month, claim_type
