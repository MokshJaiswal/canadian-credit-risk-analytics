-- =============================================================================
-- 01 · Load the source files into the warehouse, exactly as they are
-- =============================================================================
-- No cleaning or renaming here. If a later step has a bug, we can rebuild
-- everything from these raw copies without re-fetching or re-simulating.
--
--   raw.rates        REAL      Bank of Canada monthly rates   (src/fetch_rates.py)
--   raw.loans        SIMULATED one row per loan              (notebook 01)
--   raw.loan_months  SIMULATED one row per loan per month    (notebook 02)
--   raw.assumptions  config values the SQL needs (loaded by notebook 03 from
--                    config/pipeline.yml, so no numbers are typed into SQL)

CREATE SCHEMA IF NOT EXISTS raw;

CREATE OR REPLACE TABLE raw.rates AS
SELECT * FROM read_csv('data/rates.csv', auto_detect = true);

CREATE OR REPLACE TABLE raw.loans AS
SELECT * FROM read_csv('data/loans.csv', auto_detect = true);

CREATE OR REPLACE TABLE raw.loan_months AS
SELECT * FROM read_parquet('data/loan_months.parquet');
