"""Fetch real macro data from public Canadian sources.

Output grain everywhere: one row per (month, geo, metric).
The `source` column is stamped later by the orchestrator, because only it
knows which tier (live API / committed snapshot / synthetic) supplied a row.

Run: python -m ccra.ingest
"""
import time

import pandas as pd
import requests

from ccra.config import load_config


def get_with_retry(url: str, params: dict, max_attempts: int, backoff_seconds: float) -> requests.Response:
    """Public APIs sometimes fail for a moment, so try a few times,
    waiting twice as long each time (2s, 4s, 8s)."""
    for attempt in range(1, max_attempts + 1):
        try:
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()  # turns 4xx/5xx status codes into errors
            return response
        except requests.RequestException as error:
            if attempt == max_attempts:
                raise
            wait = backoff_seconds * 2 ** (attempt - 1)
            print(f"  attempt {attempt} failed ({error}), retrying in {wait}s")
            time.sleep(wait)


def valet_to_monthly(observations: list, series_id: str, metric: str) -> pd.DataFrame:
    """Turn Valet's daily/weekly observations into one row per month.

    Monthly AVERAGE, not month-end: we use these rates to price loans
    originated during the month, so the typical rate across the month is
    what a borrower could have locked in.
    """
    # Each observation looks like {"d": "2026-09-01", "V39079": {"v": "2.25"}}
    daily = pd.DataFrame(
        {
            "date": [obs["d"] for obs in observations],
            "value": [obs[series_id]["v"] for obs in observations],
        }
    )
    daily["date"] = pd.to_datetime(daily["date"])
    # Blanks become NaN, which mean() skips - a blank must not count as 0%
    daily["value"] = pd.to_numeric(daily["value"], errors="coerce")

    daily["month"] = daily["date"].dt.to_period("M").dt.to_timestamp()  # first of month
    monthly = daily.groupby("month", as_index=False)["value"].mean()
    monthly["geo"] = "CA"  # national series
    monthly["metric"] = metric
    return monthly[["month", "geo", "metric", "value"]]


def fetch_valet(config: dict) -> pd.DataFrame:
    """Every configured Valet series, stacked into one tidy table."""
    valet = config["sources"]["valet"]
    retry = config["sources"]["retry"]
    params = {
        "start_date": config["window"]["macro_start"],
        "end_date": config["window"]["performance_end"],  # a full month, no partial averages
    }
    frames = []
    for metric, series_id in valet["series"].items():
        print(f"Valet: {metric} ({series_id})")
        url = valet["url"].format(series=series_id)
        response = get_with_retry(url, params, retry["max_attempts"], retry["backoff_seconds"])
        frames.append(valet_to_monthly(response.json()["observations"], series_id, metric))
    return pd.concat(frames, ignore_index=True)


if __name__ == "__main__":
    config = load_config()
    macro = fetch_valet(config)
    print(f"\n{len(macro)} rows")
    print(macro.groupby("metric")["month"].agg(["count", "min", "max"]))
    # Spot-check against the brief: Jan 2021 GoC 5yr ~0.43%, policy 0.25%
    print("\nJan 2021:")
    print(macro[macro["month"] == "2021-01-01"].to_string(index=False))
