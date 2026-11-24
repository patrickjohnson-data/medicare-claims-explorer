-- Medicare spending by primary diagnosis.
-- Each claim counts once, under its primary diagnosis only, so no money is
-- double-counted.

select
    c.primary_dx_code                                   as dx_code,
    coalesce(icd.long_description, 'Unknown code')     as dx_description,
    count(*)                                            as claim_count,
    count(distinct c.member_id)                         as member_count,
    sum(c.payment_amount)                               as total_payment,
    round(avg(c.payment_amount), 2)                     as avg_payment_per_claim
from {{ ref('fct_claims') }} as c
left join {{ ref('icd9_diagnoses') }} as icd
    on icd.icd9_code = c.primary_dx_code
where c.primary_dx_code is not null
group by c.primary_dx_code, icd.long_description
