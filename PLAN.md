# Medicare Claims Cost Explorer — Plan

**Question:** Where does Medicare money go, and which providers bill in ways that look unusual?

**Data:** CMS DE-SynPUF Sample 1 — synthetic Medicare claims, 2008–2010, ICD-9 codes.

**Flow:** CSVs → Python load → DuckDB `raw` → dbt staging → intermediate → marts → anomaly flags → README

## Ground rules

- Free tools only: Python (uv, Python 3.12), dbt Core v1 + dbt-duckdb, DuckDB.
- Python handles ingestion (download and load). All transformations live in dbt SQL.
- Large data files and the DuckDB file are gitignored.

## Design choices (decided up front)

- **Use less data:** load Carrier **1A only** (not 1B), and delete the unzipped CSVs after a successful load.
- **Keep the member population consistent:** step 2 confirmed that the carrier files are split by member ID. Carrier 1A holds every member with an ID up to `7F1460C68FD409E9` (58,092 of 116,352 members). In dbt staging, members, inpatient and outpatient are limited to that same ID range, so every table covers the same people with complete claims. Members in the range who have no carrier claims are kept; they simply had no doctor bills.
- **No 2010 member file:** CMS's 2010 beneficiary link for Sample 1 points to Sample 20's file, so only 2008 and 2009 are loaded. Every claim (2008–2010) still matches a member, because every member appears in the 2008 file. Only the 2010 yearly fields (such as chronic conditions) are missing.
- **Raw is all text:** raw tables load every column as VARCHAR. Type casting happens in dbt staging.
- **ICD-9 descriptions:** the CMS ICD-9 diagnosis descriptions file is added as a dbt seed.
- **Layout:** Python in `scripts/`, the dbt project in `dbt/` (with a committed `profiles.yml`), data in `data/` (gitignored).

## Steps

- [x] **1. Repo and Python setup**: git init, .gitignore, commit PLAN.md, uv project (Python 3.12, duckdb, dbt-core <2, dbt-duckdb), private GitHub repo.
- [x] **2. Download and load**: `scripts/download.py` (5 zips from CMS) and `scripts/load_raw.py` (CSV → DuckDB `raw` schema, row counts, delete CSVs). Confirmed that Carrier 1A is split by member ID.
- [x] **3. dbt staging**: dbt project setup, sources, one `stg_` model per source (casts, dates, renames), ICD-9 seed.
- [x] **4. Intermediate and marts**: unpivot diagnoses, combine the claim types; `dim_members`, `fct_claims`, `fct_claim_diagnoses`; cost marts by diagnosis, by provider and by month. Simplified: no `dim_providers` (the data has no provider details beyond an ID) and no carrier line unpivot (a carrier claim's lines almost always share one doctor, so line 1's doctor is the claim's provider).
- [x] **5. Tests**: built-in tests on the marts (unique, not null, accepted values, relationships) plus custom SQL tests: claims end within 2008–2010 and not before they start; at most one primary diagnosis per claim. Dropped "non-negative payments" because the data has real negative adjustments, and "line totals match claim totals" to keep things simple. The mart totals were reconciled with staging by hand once.
- [x] **6. Anomaly flags in SQL**: `provider_flags` compares each provider's average payment per claim and claims per member with peers of the same claim type. A provider (with 30+ claims) is flagged if it is in the top 1% of its peers on either measure (`PERCENT_RANK`). Chosen over a robust z-score because it is simple to read and explain. Result: 120 of 6,055 providers flagged.
- [ ] ~~**7. Ollama explanations**~~: skipped to keep the project focused on the data pipeline.
- [ ] **8. README and make the repo public**: findings, design choices, limitations (synthetic data; a flag is not proof of fraud), how to run it.
