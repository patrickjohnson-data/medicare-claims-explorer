-- Doctor and supplier bills (Carrier file 1A). One row per claim.
-- Each claim has up to 13 line items, stored as numbered columns.
-- Carrier claims have no claim-level payment; the lines hold the money.

select
    clm_id                                      as claim_id,
    desynpuf_id                                 as member_id,
    cast(strptime(clm_from_dt, '%Y%m%d') as date)  as claim_start_date,
    cast(strptime(clm_thru_dt, '%Y%m%d') as date)  as claim_end_date,

    -- Diagnosis codes 1-8
    icd9_dgns_cd_1                              as dx_code_1,
    icd9_dgns_cd_2                              as dx_code_2,
    icd9_dgns_cd_3                              as dx_code_3,
    icd9_dgns_cd_4                              as dx_code_4,
    icd9_dgns_cd_5                              as dx_code_5,
    icd9_dgns_cd_6                              as dx_code_6,
    icd9_dgns_cd_7                              as dx_code_7,
    icd9_dgns_cd_8                              as dx_code_8,

    -- Line items 1-13: the performing doctor (NPI) and what Medicare paid
    prf_physn_npi_1                             as line_1_npi,
    cast(line_nch_pmt_amt_1 as decimal(12, 2))  as line_1_payment_amount,
    prf_physn_npi_2                             as line_2_npi,
    cast(line_nch_pmt_amt_2 as decimal(12, 2))  as line_2_payment_amount,
    prf_physn_npi_3                             as line_3_npi,
    cast(line_nch_pmt_amt_3 as decimal(12, 2))  as line_3_payment_amount,
    prf_physn_npi_4                             as line_4_npi,
    cast(line_nch_pmt_amt_4 as decimal(12, 2))  as line_4_payment_amount,
    prf_physn_npi_5                             as line_5_npi,
    cast(line_nch_pmt_amt_5 as decimal(12, 2))  as line_5_payment_amount,
    prf_physn_npi_6                             as line_6_npi,
    cast(line_nch_pmt_amt_6 as decimal(12, 2))  as line_6_payment_amount,
    prf_physn_npi_7                             as line_7_npi,
    cast(line_nch_pmt_amt_7 as decimal(12, 2))  as line_7_payment_amount,
    prf_physn_npi_8                             as line_8_npi,
    cast(line_nch_pmt_amt_8 as decimal(12, 2))  as line_8_payment_amount,
    prf_physn_npi_9                             as line_9_npi,
    cast(line_nch_pmt_amt_9 as decimal(12, 2))  as line_9_payment_amount,
    prf_physn_npi_10                            as line_10_npi,
    cast(line_nch_pmt_amt_10 as decimal(12, 2)) as line_10_payment_amount,
    prf_physn_npi_11                            as line_11_npi,
    cast(line_nch_pmt_amt_11 as decimal(12, 2)) as line_11_payment_amount,
    prf_physn_npi_12                            as line_12_npi,
    cast(line_nch_pmt_amt_12 as decimal(12, 2)) as line_12_payment_amount,
    prf_physn_npi_13                            as line_13_npi,
    cast(line_nch_pmt_amt_13 as decimal(12, 2)) as line_13_payment_amount

from {{ source('raw', 'carrier_claims') }}
