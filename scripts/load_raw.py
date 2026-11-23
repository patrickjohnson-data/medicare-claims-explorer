"""Load the downloaded CSVs into the DuckDB `raw` schema.

Usage:
    uv run python scripts/load_raw.py              # load, then delete the CSVs
    uv run python scripts/load_raw.py --keep-csv   # load and keep the CSVs

Every column is loaded as text (VARCHAR). Type casting happens in the dbt
staging models, so raw stays an exact copy of the source files.

Each raw table gets two extra columns:
    _source_file  which CSV the row came from
    _loaded_at    when the load ran
"""

import argparse
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = REPO_ROOT / "data" / "csv"
DB_PATH = REPO_ROOT / "data" / "medicare.duckdb"

# raw table name -> filename pattern(s) in data/csv/.
# The two beneficiary years go into one table; _source_file tells them apart.
TABLES = {
    "beneficiary_summary": "DE1_0_*_Beneficiary_Summary_File_Sample_1.csv",
    "inpatient_claims": "DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.csv",
    "outpatient_claims": "DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.csv",
    "carrier_claims": "DE1_0_2008_to_2010_Carrier_Claims_Sample_1A.csv",
}


def load_table(con: duckdb.DuckDBPyConnection, table: str, pattern: str) -> int:
    """(Re)create raw.<table> from the CSV(s) matching pattern. Returns row count."""
    files = sorted(CSV_DIR.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No CSV matches {pattern} in {CSV_DIR}")

    # DuckDB's read_csv accepts a list of files and stacks them (like UNION ALL).
    # all_varchar = load every column as text; filename = add the source path.
    file_list = [f.as_posix() for f in files]
    con.execute(
        f"""
        create or replace table raw.{table} as
        select
            * exclude (filename),
            regexp_extract(filename, '[^/]+$') as _source_file,
            current_timestamp as _loaded_at
        from read_csv(?, header = true, all_varchar = true, filename = true)
        """,
        [file_list],
    )
    return con.execute(f"select count(*) from raw.{table}").fetchone()[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--keep-csv", action="store_true", help="don't delete CSVs after loading"
    )
    args = parser.parse_args()

    # `with` closes the database connection automatically, even on an error.
    with duckdb.connect(str(DB_PATH)) as con:
        con.execute("create schema if not exists raw")
        for table, pattern in TABLES.items():
            print(f"loading raw.{table} ...", flush=True)
            rows = load_table(con, table, pattern)
            print(f"  {rows:>12,} rows")

    print(f"\nDatabase: {DB_PATH} ({DB_PATH.stat().st_size / 1_000_000:,.0f} MB)")

    # Only reached if every table loaded (an error above stops the script).
    if not args.keep_csv:
        for csv in CSV_DIR.glob("*.csv"):
            csv.unlink()
        print("CSVs deleted (re-run download.py to get them back from the zips).")


if __name__ == "__main__":
    main()
