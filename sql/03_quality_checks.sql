-- =============================================================================
-- 03 · Data quality checks
-- =============================================================================
-- Each check counts the rows that BREAK a rule. 0 = pass.
-- severity 'error'   -> the build stops (notebook 03 raises an error)
-- severity 'warning' -> reported, but the build continues
--
-- Five kinds of check (what bank data teams look for):
--   completeness   - required values are not missing
--   uniqueness     - no duplicate keys
--   validity       - values are in an allowed range / list
--   consistency    - tables agree with each other (every fact row has a loan)
--   reconciliation - totals in the warehouse match the source files

CREATE SCHEMA IF NOT EXISTS quality;

CREATE OR REPLACE TABLE quality.check_results AS

-- COMPLETENESS -----------------------------------------------------------------
SELECT 'completeness' AS dimension, 'Every loan has a product, province and credit score' AS check_name, 'error' AS severity,
       (SELECT COUNT(*) FROM mart.dim_loan
        WHERE product IS NULL OR province IS NULL OR credit_score IS NULL) AS failed_rows
UNION ALL
SELECT 'completeness', 'Every month in the data has all four real rates', 'error',
       (SELECT COUNT(*) FROM mart.dim_month
        WHERE month <= (SELECT MAX(month) FROM raw.rates)
          AND (policy_rate IS NULL OR prime_rate IS NULL OR goc_5yr_yield IS NULL OR posted_5yr_mortgage IS NULL))
UNION ALL
SELECT 'completeness', 'Every renewing mortgage has old and new payment', 'error',
       (SELECT COUNT(*) FROM mart.fact_renewal WHERE old_payment IS NULL OR new_payment IS NULL)

-- UNIQUENESS -------------------------------------------------------------------
UNION ALL
SELECT 'uniqueness', 'loan_id is unique in dim_loan', 'error',
       (SELECT COUNT(*) - COUNT(DISTINCT loan_id) FROM mart.dim_loan)
UNION ALL
SELECT 'uniqueness', 'One row per loan per month in fact_loan_month', 'error',
       (SELECT COUNT(*) FROM (SELECT loan_id, month FROM mart.fact_loan_month
                              GROUP BY loan_id, month HAVING COUNT(*) > 1))
UNION ALL
SELECT 'uniqueness', 'One row per month in dim_month', 'error',
       (SELECT COUNT(*) - COUNT(DISTINCT month) FROM mart.dim_month)

-- VALIDITY ---------------------------------------------------------------------
UNION ALL
SELECT 'validity', 'Credit scores between 300 and 900', 'error',
       (SELECT COUNT(*) FROM mart.dim_loan WHERE credit_score NOT BETWEEN 300 AND 900)
UNION ALL
SELECT 'validity', 'Balances are not negative', 'error',
       (SELECT COUNT(*) FROM mart.fact_loan_month WHERE balance < 0)
UNION ALL
SELECT 'validity', 'Status is one of the six allowed values', 'error',
       (SELECT COUNT(*) FROM mart.fact_loan_month WHERE status_order IS NULL)
UNION ALL
SELECT 'validity', 'Interest rates between 0% and 30%', 'error',
       (SELECT COUNT(*) FROM mart.dim_loan WHERE rate_at_signing NOT BETWEEN 0 AND 30)
UNION ALL
SELECT 'validity', 'Fixed mortgage rates at or above the config floor (1.35%)', 'warning',
       (SELECT COUNT(*) FROM mart.dim_loan
        WHERE product = 'mortgage' AND rate_type = 'fixed'
          AND rate_at_signing < assumption('fixed_rate_floor'))

-- CONSISTENCY ------------------------------------------------------------------
UNION ALL
SELECT 'consistency', 'Every fact row belongs to a known loan', 'error',
       (SELECT COUNT(*) FROM mart.fact_loan_month AS f
        LEFT JOIN mart.dim_loan AS d USING (loan_id) WHERE d.loan_id IS NULL)
UNION ALL
SELECT 'consistency', 'Every fact month exists in dim_month', 'error',
       (SELECT COUNT(*) FROM mart.fact_loan_month AS f
        LEFT JOIN mart.dim_month AS m USING (month) WHERE m.month IS NULL)
UNION ALL
SELECT 'consistency', 'Delinquent balance never exceeds balance', 'error',
       (SELECT COUNT(*) FROM mart.fact_loan_month WHERE delinquent_balance > balance)
UNION ALL
SELECT 'consistency', 'No loan appears after the month it defaulted', 'error',
       (SELECT COUNT(*) FROM mart.fact_loan_month AS f
        JOIN (SELECT loan_id, month AS default_month FROM mart.fact_loan_month WHERE status = 'default') AS d
          USING (loan_id)
        WHERE f.month > d.default_month)

-- RECONCILIATION ---------------------------------------------------------------
UNION ALL
SELECT 'reconciliation', 'Loan count: source file vs dim_loan', 'error',
       ABS((SELECT COUNT(*) FROM read_csv('data/loans.csv', auto_detect = true))
         - (SELECT COUNT(*) FROM mart.dim_loan))
UNION ALL
SELECT 'reconciliation', 'Row count: source file vs fact_loan_month', 'error',
       ABS((SELECT COUNT(*) FROM read_parquet('data/loan_months.parquet'))
         - (SELECT COUNT(*) FROM mart.fact_loan_month))
UNION ALL
-- Totals must tie within 0.01%. failed_rows = 1 if they don't.
SELECT 'reconciliation', 'Total balance: source file vs summary table (within 0.01%)', 'error',
       CASE WHEN ABS((SELECT SUM(balance) FROM read_parquet('data/loan_months.parquet'))
                   - (SELECT SUM(balance) FROM mart.agg_portfolio_monthly))
                 / (SELECT SUM(balance) FROM read_parquet('data/loan_months.parquet')) <= 0.0001
            THEN 0 ELSE 1 END;


-- Add a pass/fail column and the time of this run
CREATE OR REPLACE TABLE quality.check_results AS
SELECT
    *,
    CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CURRENT_TIMESTAMP AS checked_at
FROM quality.check_results;
