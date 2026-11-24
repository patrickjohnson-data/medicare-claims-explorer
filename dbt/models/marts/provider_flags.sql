-- Flags providers whose billing looks unusual compared with their peers.
--
-- Peers = other providers of the same claim type (inpatient, outpatient
-- or carrier). Only providers with at least 30 claims are compared, because
-- with fewer claims the averages are too noisy.
--
-- A provider is flagged if it is in the top 1% of its peers for either:
--   avg_payment_per_claim  - how much Medicare pays them per claim
--   claims_per_member      - how many claims they bill per patient
--
-- A flag is not proof of fraud, only a reason to take a closer look.

with ranked as (

    select
        claim_type,
        provider_id,
        claim_count,
        member_count,
        total_payment,
        avg_payment_per_claim,
        claims_per_member,

        -- PERCENT_RANK gives each provider a value from 0 to 1 within its
        -- claim type: 0 = lowest, 1 = highest, 0.99 = higher than 99% of peers.
        percent_rank() over (partition by claim_type order by avg_payment_per_claim)
                                                    as payment_percentile,
        percent_rank() over (partition by claim_type order by claims_per_member)
                                                    as claims_per_member_percentile

    from {{ ref('cost_by_provider') }}
    where claim_count >= 30

)

select
    *,
    payment_percentile >= 0.99                      as is_high_payment,
    claims_per_member_percentile >= 0.99            as is_high_claims_per_member,
    payment_percentile >= 0.99
        or claims_per_member_percentile >= 0.99     as is_flagged
from ranked
