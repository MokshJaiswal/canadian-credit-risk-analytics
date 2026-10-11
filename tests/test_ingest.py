"""Tests for the analysis logic in ingest.py. No network needed.
Run: python -m pytest tests -v
"""
import pandas as pd

from ccra.ingest import valet_to_monthly


def test_valet_is_averaged_to_months_and_skips_blanks():
    # Same shape the Bank of Canada API returns
    observations = [
        {"d": "2021-01-04", "V1": {"v": "1.0"}},
        {"d": "2021-01-05", "V1": {"v": "2.0"}},
        {"d": "2021-01-06", "V1": {"v": ""}},  # a blank must not count as 0%
        {"d": "2021-02-01", "V1": {"v": "5.0"}},
    ]
    monthly = valet_to_monthly(observations, "V1", "policy_rate")

    assert list(monthly.columns) == ["month", "geo", "metric", "value"]
    assert len(monthly) == 2  # grain: one row per month
    assert monthly["value"].tolist() == [1.5, 5.0]  # Jan = (1.0 + 2.0) / 2
    assert monthly["month"].tolist() == [pd.Timestamp("2021-01-01"), pd.Timestamp("2021-02-01")]
