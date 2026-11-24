# Medicare Claims Cost Explorer

An end-to-end analytics pipeline over synthetic Medicare claims data, built with **Python, DuckDB and dbt**. It answers two questions:

1. **Where does Medicare money go?** By care setting, diagnosis, provider and month.
2. **Which providers bill in ways that look unusual?** Compared with peers in the same care setting.

## Key findings

The figures cover 2.8 million claims and **$636M** in Medicare payments for 58,092 synthetic members, from 2008 to 2010.

**Hospital stays are about 1% of claims but half of all spending.**

| Care setting | Claims | Medicare paid | Share of spend | Avg per claim |
|---|---:|---:|---:|---:|
| Inpatient (hospital stays) | 33,455 | $317.4M | 50% | $9,489 |
| Carrier (doctor bills) | 2,370,667 | $207.3M | 33% | $87 |
| Outpatient (hospital visits) | 391,210 | $111.5M | 18% | $285 |

**Spending is concentrated in a few members.** The costliest 5% of members account for 29% of all payments, and the top 1% for 9%.

**Top diagnoses by spending** (by primary diagnosis, so each claim is counted once):

| ICD-9 | Diagnosis | Claims | Medicare paid |
|---|---|---:|---:|
| V57.89 | Rehabilitation care | 1,489 | $14.3M |
| 414.01 | Coronary artery disease | 4,033 | $13.1M |
| 038.9 | Septicemia (blood infection) | 1,048 | $12.2M |
| 486 | Pneumonia | 1,545 | $8.5M |
| 410.71 | Heart attack (subendocardial) | 755 | $8.1M |

**120 of 6,055 providers are flagged as unusual.** Examples:

- **Doctor `7137919052`:** 31 claims for a single patient. The typical doctor bills about 1.3 claims per patient.
- **Hospital `10S0NQ`:** $14,313 average per stay, against a peer median of $9,354.
- **Outpatient facility `17138K`:** $1,092 average per visit, against a peer median of $268.

## Architecture

```
CMS website ──▶ Python ──▶ DuckDB "raw" ──▶ dbt: staging ──▶ intermediate ──▶ marts
 (5 zip files)  download    (all text,         (types,        (combine claim   (facts, dimension,
                + load      as published)       renames)       types, unpivot   cost summaries,
                                                               diagnoses)       provider flags)
```

| Layer | Tool | Purpose |
|---|---|---|
| Ingestion | Python ([download.py](scripts/download.py), [load_raw.py](scripts/load_raw.py)) | Download the CMS files and load them unchanged into the `raw` schema |
| Staging | dbt views | One model per source: rename columns, cast types, filter to a consistent member population |
| Intermediate | dbt views | Combine the three claim types into one claim grain, and unpivot diagnosis codes into rows |
| Marts | dbt tables | Facts, members dimension, cost summaries and provider flags |
| Reference data | dbt seed | CMS ICD-9 diagnosis descriptions ([download_icd9.py](scripts/download_icd9.py)) |

All transformations are written in plain SQL. Jinja is used only for `ref()`, `source()` and one `var()`.

### Models

| Model | Grain | Description |
|---|---|---|
| `fct_claims` | Claim | Every claim with type, member, provider, dates, month, primary diagnosis and payment |
| `fct_claim_diagnoses` | Claim + diagnosis | Every diagnosis on every claim, with its ICD-9 description |
| `dim_members` | Member | Demographics and chronic conditions, taken from the latest year on file |
| `cost_by_month` | Month + claim type | Claims, members and payments per month |
| `cost_by_diagnosis` | Primary diagnosis | Claims, members, total and average payment |
| `cost_by_provider` | Provider + claim type | Volume, total and average payment, claims per member |
| `provider_flags` | Provider + claim type | Peer percentiles and anomaly flags |

## Anomaly method

Each provider with **at least 30 claims** is compared with others of the **same claim type** (inpatient, outpatient or carrier) on two measures:

- **Average payment per claim:** is Medicare paying this provider much more per claim than its peers?
- **Claims per member:** is this provider billing the same patients unusually often?

A provider is flagged if it falls in the **top 1% of its peers** on either measure, using `PERCENT_RANK()`. This method was chosen over a robust z-score because it's transparent, easy to explain and gives a predictable number of flags.

A flag is a prompt for review, **not evidence of fraud**. A high average payment can reflect sicker patients or more complex procedures.

## Data quality and validation

Every result was validated during development, not just generated:

- **Reconciliation:** claim counts and payment totals in the marts were reconciled against staging for each claim type, and they match exactly.
- **Profiling before modeling:** the raw data was profiled before each model was designed, covering grain, null rates, code values, date formats and how the ID ranges split across files. This surfaced the quirks below.
- **Automated tests:** 14 dbt tests run on every build. They check uniqueness and not-null on keys, accepted values, referential integrity between facts and dimensions, valid claim date ranges, and at most one primary diagnosis per claim.
- **Reviewing logs and output:** dbt build logs, test output and sample rows were checked after every change.

**Data quirks found and how they're handled:**

- **Claim segments:** some inpatient and outpatient claims span two rows. Segment 2 carries payments but no dates. Segments are merged into one claim, and the payments are summed.
- **139 outpatient claims have only a segment 2 row.** They're kept, with no dates.
- **Negative payments** (about 1,300 claims) are real adjustments and are kept.
- **Claims starting in late 2007:** 263 hospital claims started before 2008 and ended in 2008. They're valid and kept.
- **About 3% of diagnosis codes** don't match the CMS ICD-9 list, mostly shortened codes in the synthetic data. They're labeled "Unknown code".

## Design choices

- **Consistent member population:** the doctor-claims file (Carrier) is published in two halves, split by member ID. Only the first half is used, and members, inpatient and outpatient claims are filtered to the same ID range. Every table covers the same 58,092 people, with complete claims.
- **Raw stays raw:** every raw column is loaded as text, exactly as published. All typing and cleanup happens in dbt staging.
- **Simplicity over cleverness:** plain SQL, one schema and a small number of models. No provider dimension was built, because the data has only a provider ID.
- **Free and local:** DuckDB is a single file with no server, and every tool is open source.

## Limitations

- **Synthetic data.** CMS DE-SynPUF is designed for learning and testing. Findings don't describe real Medicare patients or providers.
- **2010 is incomplete.** CMS doesn't publish a usable 2010 member file for this sample, and 2010 claim spending ($143M) is well below 2008 ($241M) and 2009 ($250M). Year-over-year comparisons that include 2010 should be read with care.
- **Half of the doctor claims.** Only Carrier file 1A is used, which covers 58,092 of 116,352 members.
- **A provider is an ID only.** There are no names, specialties or locations, so peers are grouped by claim type only.

## How to run

You need [uv](https://docs.astral.sh/uv/). It installs Python 3.12 and all dependencies.

```bash
uv sync                                  # install Python and packages
uv run python scripts/download.py        # download CMS files (~150 MB of zips)
uv run python scripts/load_raw.py        # load into data/medicare.duckdb (~860 MB)

cd dbt
uv run dbt build                         # seed, build all models, run all tests
uv run dbt docs generate                 # optional: docs site with lineage graph
uv run dbt docs serve
```

The ICD-9 seed is committed. Run `uv run python scripts/download_icd9.py` only if you want to regenerate it.

## Project structure

```
scripts/            Python ingestion (download, load, ICD-9 seed)
dbt/
  models/staging/       one model per raw table, plus source definitions
  models/intermediate/  claim and diagnosis combining logic
  models/marts/         facts, dimension, cost summaries, provider flags, tests
  seeds/                ICD-9 diagnosis descriptions
  tests/                custom SQL tests
data/               downloaded files and DuckDB database (not committed)
PLAN.md             project plan and design decisions
```

## How this was built

I developed this project with an AI coding assistant (Claude Code), working the way I would with a pair programmer. I owned the scope, design and decisions: the member population, the modeling approach, the testing strategy, the anomaly method, and an overall rule to keep the SQL simple and readable. The assistant drafted code from those decisions.

I reviewed and validated every step myself:
- I compared results between layers and reconciled totals.
- I profiled the data and inspected sample output.
- I read the dbt logs and test results.
- I pushed back where code was more complex than it needed to be.

Several simplifications came out of that review: replacing Jinja loops with plain SQL, dropping a custom schema macro, and replacing a statistical z-score with a percentile rule.

## Data source

[CMS 2008–2010 Data Entrepreneurs' Synthetic Public Use File (DE-SynPUF)](https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files), Sample 1. The ICD-9 descriptions are from [CMS ICD-9-CM version 32](https://www.cms.gov/medicare/coding-billing/icd-10-codes/icd-9-cm-diagnosis-procedure-codes-abbreviated-and-full-code-titles).
