#!/usr/bin/env python3
"""Prepare clean PhonePe Pulse CSV copies from the six supplied source files.

Usage:
  python prepare_phonepe_data.py --input-dir ../raw_data --output-dir ../cleaned_data
Requires pandas.
"""
from pathlib import Path
import argparse
import pandas as pd

STATE_OVERRIDES = {
    "andaman-&-nicobar-islands": "Andaman and Nicobar Islands",
    "andhra-pradesh": "Andhra Pradesh",
    "arunachal-pradesh": "Arunachal Pradesh",
    "dadra-&-nagar-haveli-&-daman-&-diu": "Dadra and Nagar Haveli and Daman and Diu",
    "jammu-&-kashmir": "Jammu and Kashmir",
    "himachal-pradesh": "Himachal Pradesh",
    "madhya-pradesh": "Madhya Pradesh",
    "tamil-nadu": "Tamil Nadu",
    "uttar-pradesh": "Uttar Pradesh",
    "uttarakhand": "Uttarakhand",
    "west-bengal": "West Bengal",
}
FILES = {
    "top_user.csv": "top_user.csv",
    "top_transaction(1).csv": "top_transaction.csv",
    "map_user.csv": "map_user.csv",
    "map_transaction.csv": "map_transaction.csv",
    "aggregated_user.csv": "aggregated_user.csv",
    "aggregated_transaction.csv": "aggregated_transaction.csv",
}

def state_display(value):
    if value in STATE_OVERRIDES:
        return STATE_OVERRIDES[value]
    return value.replace("-&-", " and ").replace("&", "and").replace("-", " ").title()

def clean_file(path, output_dir):
    df = pd.read_csv(path)
    # Remove only exported index columns; preserve all business columns.
    df = df.loc[:, ~df.columns.astype(str).str.match(r"^Unnamed")].copy()
    required = {"states", "year", "quarter"}
    missing = required.difference(df.columns)
    if missing:
        raise ValueError(f"{path.name}: missing required columns {sorted(missing)}")
    df["state_display"] = df["states"].map(state_display)
    df["country"] = "India"
    month = (df["quarter"] - 1) * 3 + 1
    df["quarter_start_date"] = pd.to_datetime(
        df["year"].astype(str) + "-" + month.astype(str).str.zfill(2) + "-01"
    )
    df["year_quarter"] = df["year"].astype(str) + " Q" + df["quarter"].astype(str)
    df["year_quarter_sort"] = df["year"] * 10 + df["quarter"]
    if "district" in df.columns:
        df["district_clean"] = (
            df["district"].astype(str)
            .str.replace(r"\s+district$", "", regex=True)
            .str.strip().str.lower()
        )
    output_dir.mkdir(parents=True, exist_ok=True)
    out_path = output_dir / path.name
    df.to_csv(out_path, index=False)
    return out_path, len(df), int(df.isna().sum().sum()), int(df.duplicated().sum())

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    results = []
    for source_filename, output_filename in FILES.items():
        source = args.input_dir / source_filename
        if not source.exists():
            raise FileNotFoundError(f"Required source file not found: {source}")
        # Clean using the source file's real name, then normalize the output name
        # so Power BI/SQL table names remain consistent.
        out_path, rows, missing, duplicates = clean_file(source, args.output_dir)
        normalized_path = args.output_dir / output_filename
        if out_path != normalized_path:
            out_path.replace(normalized_path)
        results.append((normalized_path, rows, missing, duplicates))
    print("Cleaned files:")
    for path, rows, missing, duplicates in results:
        print(f"- {path.name}: {rows:,} rows | missing cells: {missing} | exact duplicates: {duplicates}")
    print("Note: no joins or aggregation are performed by this script.")

if __name__ == "__main__":
    main()
