"""Download the CMS ICD-9 diagnosis descriptions and write them as a dbt seed.

Usage:
    uv run python scripts/download_icd9.py

Output: dbt/seeds/icd9_diagnoses.csv (committed to git; it's small).

Source: CMS ICD-9-CM version 32 (the final ICD-9 release, 2014). The zip
holds two fixed-format text files for diagnoses, one with short and one
with long descriptions. Each line is "<code> <description>", e.g.
    4280  Congestive heart failure, unspecified

Codes have no decimal point ("4280" means 428.0), matching the claims data.

Coverage note: about 97% of the diagnosis codes used in the claims match a
v32 code. Most misses are synthetic-data quirks, such as truncated category
codes like "585" (never a billable code) and the placeholder "OTHER". Older
ICD-9 versions (v27, v28) were checked and add almost nothing.
"""

import csv
import io
import urllib.request
import zipfile
from pathlib import Path

URL = (
    "https://www.cms.gov/medicare/coding/icd9providerdiagnosticcodes/"
    "downloads/icd-9-cm-v32-master-descriptions.zip"
)
SHORT_FILE = "CMS32_DESC_SHORT_DX.txt"
LONG_FILE = "CMS32_DESC_LONG_DX.txt"

REPO_ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = REPO_ROOT / "dbt" / "seeds" / "icd9_diagnoses.csv"


def read_descriptions(zf: zipfile.ZipFile, name: str) -> dict[str, str]:
    """Return {code: description} from one of the CMS text files."""
    descriptions = {}
    # The long file uses Latin-1 (e.g. "Ménière's disease"), not UTF-8.
    # Latin-1 also reads plain ASCII, so it's safe for the short file too.
    with zf.open(name) as raw:
        for line in io.TextIOWrapper(raw, encoding="latin-1"):
            line = line.strip()
            if not line:
                continue
            # split(maxsplit=1) splits on the first run of spaces only:
            # "4280  Congestive heart failure" -> ["4280", "Congestive heart failure"]
            code, description = line.split(maxsplit=1)
            # A few descriptions contain double quotes ('"Ventilation"
            # pneumonitis'). Valid CSV escapes them as "", but DuckDB's CSV
            # sniffer (used by dbt seed) guesses the format from a sample
            # and fails on them. Single quotes keep the meaning and need
            # no escaping.
            descriptions[code] = description.replace('"', "'")
    return descriptions


def main() -> None:
    print(f"downloading: {URL.rsplit('/', 1)[-1]} ...", flush=True)
    request = urllib.request.Request(URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request) as response:
        # The zip is ~1 MB, so reading it into memory is fine.
        # io.BytesIO wraps the bytes so ZipFile can treat them like a file.
        zf = zipfile.ZipFile(io.BytesIO(response.read()))

    short = read_descriptions(zf, SHORT_FILE)
    long = read_descriptions(zf, LONG_FILE)
    if short.keys() != long.keys():
        raise ValueError("short and long files have different code lists")

    SEED_PATH.parent.mkdir(parents=True, exist_ok=True)
    # newline="" stops Windows from writing blank lines between CSV rows.
    with open(SEED_PATH, "w", newline="", encoding="utf-8") as out:
        writer = csv.writer(out)
        writer.writerow(["icd9_code", "short_description", "long_description"])
        for code in sorted(short):
            writer.writerow([code, short[code], long[code]])

    print(f"wrote {len(short):,} codes to {SEED_PATH.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
