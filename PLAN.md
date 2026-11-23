# Medicare Claims Cost Explorer — Plan

**Question:** Where does Medicare money go, and which providers bill in ways that look unusual?

**Data:** CMS DE-SynPUF Sample 1 — synthetic Medicare claims, 2008–2010, ICD-9 codes.

**Flow:** CSVs → Python load → DuckDB `raw` → dbt staging → intermediate → marts → anomaly flags → Ollama explanations → seed → README

## Ground rules

- Free tools only: Python (uv, Python 3.12), dbt Core v1 + dbt-duckdb, DuckDB, Ollama.
- Python handles ingestion (download and load) and the LLM explanations. All transformations live in dbt SQL.
- Large data files and the DuckDB file are gitignored.

## Design choices (decided up front)

- **Use less data:** load Carrier **1A only** (not 1B), and delete the unzipped CSVs after a successful load.
- **Keep the member population consistent:** if the carrier files are split by member (checked in step 2), limit the beneficiary, inpatient and outpatient data to the members in Carrier 1A, so every table covers the same people with complete claims.
- **Raw is all text:** raw tables load every column as VARCHAR. Type casting happens in dbt staging.
- **ICD-9 descriptions:** the CMS ICD-9 diagnosis descriptions file is added as a dbt seed.
- **Layout:** Python in `scripts/`, the dbt project in `dbt/` (with a committed `profiles.yml`), data in `data/` (gitignored).

## Steps

- [x] **1. Repo and Python setup**: git init, .gitignore, commit PLAN.md, uv project (Python 3.12, duckdb, dbt-core <2, dbt-duckdb), private GitHub repo.
- [ ] **2. Download and load**: `scripts/download.py` (7 zips → 6 used) and `scripts/load_raw.py` (CSV → DuckDB `raw` schema, row counts, delete CSVs). Check how Carrier 1A is split and limit the members if needed.
- [ ] **3. dbt staging**: dbt project setup, sources, one `stg_` model per source (casts, dates, renames), ICD-9 seed.
- [ ] **4. Intermediate and marts**: unpivot diagnoses and carrier lines, combine the claim types; `dim_members`, `dim_providers`, `fct_claims`, `fct_claim_diagnoses`; cost marts by diagnosis, by provider and by month.
- [ ] **5. Tests**: built-in tests plus custom tests (non-negative payments, line totals match claim totals, dates within 2008–2010).
- [ ] **6. Anomaly flags in SQL**: cost per claim and claims per member compared with peers in the same care setting (robust z-score with a minimum-volume threshold; method finalized in this step).
- [ ] **7. Ollama explanations**: install Ollama and a small model; `scripts/explain_flags.py` writes `dbt/seeds/flag_explanations.csv` (committed).
- [ ] **8. README and make the repo public**: findings, design choices, limitations (synthetic data; a flag is not proof of fraud), how to run it.
