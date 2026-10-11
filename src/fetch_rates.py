# Fetch real Canadian interest rates from the Bank of Canada and save them
# as one row per month.
#
# Run from the project folder:  python src\fetch_rates.py
# Output: data/rates.csv

from pathlib import Path

import pandas as pd
import requests
import yaml

config = yaml.safe_load(open("config/pipeline.yml"))
start_date = config["window"]["macro_start"]
end_date = config["window"]["performance_end"]  # end of a full month
series = config["sources"]["valet"]["series"]   # e.g. {"policy_rate": "V39079", ...}

monthly_tables = []

for rate_name, series_id in series.items():
    print(f"Fetching {rate_name} ({series_id})")
    url = f"https://www.bankofcanada.ca/valet/observations/{series_id}/json"
    response = requests.get(url, params={"start_date": start_date, "end_date": end_date}, timeout=30)
    response.raise_for_status()  # stop with an error if the API call failed

    # Each observation looks like {"d": "2026-09-01", "V39079": {"v": "2.25"}}
    observations = response.json()["observations"]
    daily = pd.DataFrame({
        "date": [obs["d"] for obs in observations],
        "value": [obs[series_id]["v"] for obs in observations],
    })
    daily["date"] = pd.to_datetime(daily["date"])
    daily["value"] = pd.to_numeric(daily["value"], errors="coerce")  # blanks -> NaN, skipped by mean()

    # Monthly AVERAGE: the typical rate a borrower could lock in that month
    daily["month"] = daily["date"].dt.to_period("M").dt.to_timestamp()
    monthly = daily.groupby("month")["value"].mean().rename(rate_name)
    monthly_tables.append(monthly)

# One row per month, one column per rate
rates = pd.concat(monthly_tables, axis=1).reset_index()
rates["source"] = "Bank of Canada Valet API (real)"

Path("data").mkdir(exist_ok=True)
rates.to_csv("data/rates.csv", index=False)

print(f"\nSaved data/rates.csv: {len(rates)} months, {rates['month'].min():%Y-%m} to {rates['month'].max():%Y-%m}")
print("\nSpot check, January 2021 (brief says GoC 5yr ~0.43, posted 4.79):")
print(rates[rates["month"] == "2021-01-01"].to_string(index=False))
