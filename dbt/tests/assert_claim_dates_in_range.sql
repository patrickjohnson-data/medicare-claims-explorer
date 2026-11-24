-- Claims must end within the data years (2008-2010), and must not end
-- before they start.
-- Start dates are not checked against 2008: some hospital stays began in
-- late 2007 and ended in 2008, which is valid.
-- Claims with no dates (139 outpatient claims that only have a segment 2
-- row) are skipped.

select
    claim_type,
    claim_id,
    claim_start_date,
    claim_end_date
from {{ ref('fct_claims') }}
where claim_end_date < cast('2008-01-01' as date)
   or claim_end_date > cast('2010-12-31' as date)
   or claim_end_date < claim_start_date
