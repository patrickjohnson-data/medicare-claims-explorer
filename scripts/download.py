"""Download the CMS DE-SynPUF Sample 1 files and unzip them.

Usage:
    uv run python scripts/download.py

Zips go to data/zips/ and CSVs to data/csv/. Files that already exist are
skipped, so the script is safe to re-run.

Notes on file choice:
- Carrier claims ship in two halves (1A and 1B). Only 1A is used, to keep
  the data small.
- The 2010 beneficiary file for Sample 1 is not available from CMS (the
  published link points to Sample 20), so only 2008 and 2009 are used.
"""

import shutil
import urllib.request
import zipfile
from pathlib import Path

CMS_SYNPUF = (
    "https://www.cms.gov/research-statistics-data-and-systems/"
    "downloadable-public-use-files/synpufs/downloads/"
)
CMS_FILES = "https://downloads.cms.gov/files/"

DOWNLOADS = [
    CMS_SYNPUF + "DE1_0_2008_Beneficiary_Summary_File_Sample_1.zip",
    CMS_SYNPUF + "DE1_0_2009_Beneficiary_Summary_File_Sample_1.zip",
    CMS_SYNPUF + "DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.zip",
    CMS_SYNPUF + "DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.zip",
    CMS_FILES + "DE1_0_2008_to_2010_Carrier_Claims_Sample_1A.zip",
]

# Path(__file__) is this script; .parents[1] is the repo root.
REPO_ROOT = Path(__file__).resolve().parents[1]
ZIP_DIR = REPO_ROOT / "data" / "zips"
CSV_DIR = REPO_ROOT / "data" / "csv"


def download(url: str, dest: Path) -> None:
    """Download url to dest, skipping if dest already exists."""
    if dest.exists():
        print(f"  skip (already downloaded): {dest.name}")
        return

    print(f"  downloading: {dest.name} ...", flush=True)
    # Write to a temporary ".part" file first, then rename when finished.
    # If the download dies halfway, we never leave a broken zip behind
    # that a re-run would mistake for a finished one.
    part = dest.with_name(dest.name + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request) as response, open(part, "wb") as out:
        shutil.copyfileobj(response, out)  # streams in chunks, not all in memory
    part.rename(dest)
    print(f"  done: {dest.stat().st_size / 1_000_000:,.1f} MB")


def unzip_csvs(zip_path: Path, dest_dir: Path) -> None:
    """Extract only the .csv files from zip_path into dest_dir."""
    with zipfile.ZipFile(zip_path) as zf:
        for member in zf.namelist():
            if not member.lower().endswith(".csv"):
                continue
            target = dest_dir / Path(member).name
            if target.exists():
                print(f"  skip (already unzipped): {target.name}")
                continue
            print(f"  unzipping: {target.name}")
            with zf.open(member) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out)


def main() -> None:
    ZIP_DIR.mkdir(parents=True, exist_ok=True)
    CSV_DIR.mkdir(parents=True, exist_ok=True)

    for url in DOWNLOADS:
        zip_path = ZIP_DIR / url.rsplit("/", 1)[-1]
        print(zip_path.name)
        download(url, zip_path)
        unzip_csvs(zip_path, CSV_DIR)

    print("\nCSV files ready:")
    for csv in sorted(CSV_DIR.glob("*.csv")):
        print(f"  {csv.name:60} {csv.stat().st_size / 1_000_000:>8,.1f} MB")


if __name__ == "__main__":
    main()
