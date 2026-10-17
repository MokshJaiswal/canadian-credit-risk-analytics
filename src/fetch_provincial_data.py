# Fetch REAL provincial data:
#   1. Statistics Canada: monthly unemployment rate and population, by province
#   2. Canadian Bankers Association: share of mortgages 90+ days in arrears, by region
#
# Run from the project folder:  python src\fetch_provincial_data.py
# Output: data/unemployment.csv, data/mortgage_arrears.csv

from pathlib import Path

import pandas as pd
import requests
import yaml

from logger import get_logger  # src/logger.py (same folder as this script)

log = get_logger("fetch_provincial_data")

config = yaml.safe_load(open("config/pipeline.yml"))
start = pd.Timestamp(config["window"]["macro_start"])
end = pd.Timestamp(config["window"]["performance_end"]).to_period("M").to_timestamp()
Path("data").mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# 1. Statistics Canada: unemployment rate + population, one request for everything
# ---------------------------------------------------------------------------
statcan = config["sources"]["statcan"]
months_needed = (end.year - start.year) * 12 + (end.month - start.month) + 1

requests_list = []
for province, member in statcan["geography_member"].items():
    for characteristic in [statcan["unemployment_rate_member"], statcan["population_member"]]:
        # coordinate = geography . characteristic . gender(total) . age(15+) . estimate . seasonally adjusted
        coordinate = f"{member}.{characteristic}.1.1.1.1.0.0.0.0"
        requests_list.append({"productId": statcan["product_id"], "coordinate": coordinate, "latestN": months_needed + 12})

log.info(f"Fetching {len(requests_list)} StatCan series")
response = requests.post(statcan["url"], json=requests_list, timeout=60)
response.raise_for_status()

member_to_province = {member: province for province, member in statcan["geography_member"].items()}
rows = []
for item in response.json():
    if item["status"] != "SUCCESS":
        raise ValueError(f"StatCan returned {item['status']} for one series")
    series = item["object"]
    geography, characteristic = [int(x) for x in series["coordinate"].split(".")[:2]]
    measure = "unemployment_rate" if characteristic == statcan["unemployment_rate_member"] else "population_thousands"
    for point in series["vectorDataPoint"]:
        rows.append({
            "month": point["refPer"],
            "province": member_to_province[geography],
            "measure": measure,
            "value": point["value"],
        })

# One row per (month, province), one column per measure
unemployment = (
    pd.DataFrame(rows)
    .pivot_table(index=["month", "province"], columns="measure", values="value")
    .reset_index()
)
unemployment["month"] = pd.to_datetime(unemployment["month"])
unemployment = unemployment[(unemployment["month"] >= start) & (unemployment["month"] <= end)]
unemployment["source"] = "Statistics Canada table 14-10-0287 (real)"

expected = months_needed * len(statcan["geography_member"])
if len(unemployment) != expected or unemployment.isna().sum().sum() > 0:
    raise ValueError(f"Expected {expected} complete rows of unemployment data, got {len(unemployment)}")

unemployment.to_csv("data/unemployment.csv", index=False)
log.info(f"Saved data/unemployment.csv: {len(unemployment)} rows "
         f"({unemployment['province'].nunique()} geographies x {unemployment['month'].nunique()} months)")

# ---------------------------------------------------------------------------
# 2. Canadian Bankers Association: mortgages in arrears, by region
# ---------------------------------------------------------------------------
cba = config["sources"]["cba_arrears"]
log.info("Downloading CBA mortgage arrears file")
response = requests.get(cba["url"], timeout=60, headers={"User-Agent": "Mozilla/5.0"})
response.raise_for_status()
Path("data/cba_mortgage_arrears.xlsx").write_bytes(response.content)  # keep the raw file

# Each sheet has two side-by-side blocks of columns (1995-2010 and 2011 onwards):
# date | total mortgages | mortgages in arrears | arrears rate
regions = []
for region, sheet in cba["sheets"].items():
    raw = pd.read_excel("data/cba_mortgage_arrears.xlsx", sheet_name=sheet, header=None)
    for first_col in [0, 5]:
        block = raw.iloc[:, first_col:first_col + 4].copy()
        block.columns = ["month", "total_mortgages", "mortgages_in_arrears", "arrears_rate"]
        # header text like "As at:" becomes NaT and is dropped on the next line
        block["month"] = pd.to_datetime(block["month"], errors="coerce", format="mixed")
        block = block.dropna(subset=["month", "total_mortgages"])  # drops headers, notes, future months
        block["region"] = region
        regions.append(block)

arrears = pd.concat(regions, ignore_index=True)
arrears["month"] = arrears["month"].dt.to_period("M").dt.to_timestamp()  # both blocks -> first of month
arrears = arrears[(arrears["month"] >= start) & (arrears["month"] <= end)]
for col in ["total_mortgages", "mortgages_in_arrears", "arrears_rate"]:
    arrears[col] = pd.to_numeric(arrears[col])
arrears["source"] = "Canadian Bankers Association (real)"

# The CBA publishes with a lag, so the file can end a month or two before our
# window does. We keep what exists - never fill in missing months - but every
# region must cover the same months with no gaps.
months_per_region = arrears.groupby("region")["month"].agg(["min", "max", "count"])
first, last = arrears["month"].min(), arrears["month"].max()
months_available = (last.year - first.year) * 12 + (last.month - first.month) + 1
if (months_per_region["count"] != months_available).any() or arrears.duplicated(["month", "region"]).any():
    raise ValueError(f"Arrears data has gaps or duplicates:\n{months_per_region}")
if last < end:
    log.warning(f"CBA data ends {last:%Y-%m}; our window ends {end:%Y-%m} - later months are left empty")

arrears.to_csv("data/mortgage_arrears.csv", index=False)
log.info(f"Saved data/mortgage_arrears.csv: {len(arrears)} rows "
         f"({arrears['region'].nunique()} regions x {arrears['month'].nunique()} months)")

print("\nSpot check, July 2026 (CBA summary sheet: Canada 0.29%, Saskatchewan 0.46%, Quebec 0.19%):")
july = arrears[arrears["month"] == "2026-07-01"].copy()
july["arrears_pct"] = (july["arrears_rate"] * 100).round(3)
print(july[["region", "total_mortgages", "mortgages_in_arrears", "arrears_pct"]].to_string(index=False))
