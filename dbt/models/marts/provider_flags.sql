-- Flags providers whose billing looks unusual compared with other providers
-- of the same claim type (inpatient, outpatient or carrier).
--
-- Two measures per provider:
--   avg_payment_per_claim  - how much Medicare pays them per claim
--   claims_per_member      - how many claims they bill per patient
--
-- Method: robust z-score, which uses the median instead of the average, so a
-- few extreme providers can't distort the "normal" range:
--   z = 0.6745 * (value - peer median) / MAD
-- MAD (median absolute deviation) is the median distance from the median.
-- The 0.6745 scales it so z reads like a regular z-score.
-- A provider is flagged when either z is 3.5 or more (a common cut-off).
--
-- Only providers with at least 30 claims are scored; with fewer claims an
-- average is too noisy to judge. A flag is not proof of fraud, only a reason
-- to look closer.

with providers as (

    select *
    from {{ ref('cost_by_provider') }}
    where claim_count >= 30

),

peer_medians as (

    select
        claim_type,
        median(avg_payment_per_claim)   as median_payment,
        median(claims_per_member)       as median_claims_per_member
    from providers
    group by claim_type

),

peer_mads as (

    select
        p.claim_type,
        median(abs(p.avg_payment_per_claim - m.median_payment))         as mad_payment,
        median(abs(p.claims_per_member - m.median_claims_per_member))   as mad_claims_per_member
    from providers as p
    join peer_medians as m
        on m.claim_type = p.claim_type
    group by p.claim_type

),

scored as (

    select
        p.claim_type,
        p.provider_id,
        p.claim_count,
        p.member_count,
        p.total_payment,

        p.avg_payment_per_claim,
        m.median_payment                                    as peer_median_payment,
        round(0.6745 * (p.avg_payment_per_claim - m.median_payment)
              / d.mad_payment, 2)                           as payment_z_score,

        p.claims_per_member,
        m.median_claims_per_member                          as peer_median_claims_per_member,
        round(0.6745 * (p.claims_per_member - m.median_claims_per_member)
              / d.mad_claims_per_member, 2)                 as claims_per_member_z_score

    from providers as p
    join peer_medians as m
        on m.claim_type = p.claim_type
    join peer_mads as d
        on d.claim_type = p.claim_type

)

select
    *,
    payment_z_score >= 3.5                                  as is_high_payment,
    claims_per_member_z_score >= 3.5                        as is_high_claims_per_member,
    payment_z_score >= 3.5 or claims_per_member_z_score >= 3.5
                                                            as is_flagged
from scored
