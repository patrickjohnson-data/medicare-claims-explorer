-- One row per claim per diagnosis code.
--
-- UNPIVOT turns the wide dx_code_1 ... dx_code_N columns into rows, the same
-- way it works in SQL Server, and drops empty (null) codes.
--
-- The primary diagnosis is dx_code_1 on segment 1 (the main reason for the
-- claim). Carrier claims have no segments, so they count as segment 1.

with all_diagnoses as (

    select 'inpatient' as claim_type, claim_id, segment, dx_position, dx_code
    from {{ ref('stg_inpatient_claims') }}
    unpivot (dx_code for dx_position in (
        dx_code_1, dx_code_2, dx_code_3, dx_code_4, dx_code_5,
        dx_code_6, dx_code_7, dx_code_8, dx_code_9, dx_code_10
    )) as u

    union all

    select 'outpatient' as claim_type, claim_id, segment, dx_position, dx_code
    from {{ ref('stg_outpatient_claims') }}
    unpivot (dx_code for dx_position in (
        dx_code_1, dx_code_2, dx_code_3, dx_code_4, dx_code_5,
        dx_code_6, dx_code_7, dx_code_8, dx_code_9, dx_code_10
    )) as u

    union all

    select 'carrier' as claim_type, claim_id, 1 as segment, dx_position, dx_code
    from {{ ref('stg_carrier_claims') }}
    unpivot (dx_code for dx_position in (
        dx_code_1, dx_code_2, dx_code_3, dx_code_4,
        dx_code_5, dx_code_6, dx_code_7, dx_code_8
    )) as u

)

-- The same code can appear twice on one claim (e.g. on both segments),
-- so group to one row per claim + code.
select
    claim_type,
    claim_id,
    dx_code,
    max(case when segment = 1 and dx_position = 'dx_code_1' then 1 else 0 end) = 1
                                                        as is_primary
from all_diagnoses
group by claim_type, claim_id, dx_code
