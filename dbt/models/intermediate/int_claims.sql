-- One row per claim, all three claim types stacked together.
--
-- Inpatient and outpatient claims can have two segments (rows). Segment 2
-- has no dates, so min/max over the segments picks up segment 1's dates
-- (min and max skip nulls). The provider comes from segment 1 (or from
-- segment 2 for the 139 claims that only have a segment 2 row), and
-- payments are summed across both segments.
--
-- Carrier claims are one row each. Their payment is the sum of the 13 line
-- amounts, and the provider is the doctor on line 1 (lines on the same claim
-- almost always share one doctor).

with inpatient as (

    select
        'inpatient'                                         as claim_type,
        claim_id,
        member_id,
        coalesce(max(case when segment = 1 then provider_id end),
                 max(provider_id))                          as provider_id,
        min(claim_start_date)                               as claim_start_date,
        max(claim_end_date)                                 as claim_end_date,
        sum(payment_amount)                                 as payment_amount
    from {{ ref('stg_inpatient_claims') }}
    group by claim_id, member_id

),

outpatient as (

    select
        'outpatient'                                        as claim_type,
        claim_id,
        member_id,
        coalesce(max(case when segment = 1 then provider_id end),
                 max(provider_id))                          as provider_id,
        min(claim_start_date)                               as claim_start_date,
        max(claim_end_date)                                 as claim_end_date,
        sum(payment_amount)                                 as payment_amount
    from {{ ref('stg_outpatient_claims') }}
    group by claim_id, member_id

),

carrier as (

    select
        'carrier'                                           as claim_type,
        claim_id,
        member_id,
        line_1_npi                                          as provider_id,
        claim_start_date,
        claim_end_date,
        line_1_payment_amount + line_2_payment_amount + line_3_payment_amount
            + line_4_payment_amount + line_5_payment_amount + line_6_payment_amount
            + line_7_payment_amount + line_8_payment_amount + line_9_payment_amount
            + line_10_payment_amount + line_11_payment_amount + line_12_payment_amount
            + line_13_payment_amount                        as payment_amount
    from {{ ref('stg_carrier_claims') }}

)

select * from inpatient
union all
select * from outpatient
union all
select * from carrier
