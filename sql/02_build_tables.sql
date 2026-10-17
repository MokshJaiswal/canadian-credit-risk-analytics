-- =============================================================================
-- 02 · Build the analysis tables (star schema + summary tables)
-- =============================================================================
-- Star schema = small "dimension" tables that describe things (month, province,
-- product, credit band, loan) and "fact" tables that hold the numbers.
--
-- Rule used throughout: store AMOUNTS (delinquent_balance), never ratios
-- (delinquency_rate). Ratios are calculated later as SUM(...) / SUM(...),
-- which stays correct under any filter.

CREATE SCHEMA IF NOT EXISTS mart;

-- A small helper: read one config value by name
CREATE OR REPLACE MACRO assumption(setting) AS
    (SELECT value FROM raw.assumptions WHERE name = setting);


-- -----------------------------------------------------------------------------
-- DIMENSIONS
-- -----------------------------------------------------------------------------

-- One row per month, Jan 2015 - Dec 2027, with the REAL rates where we have them.
-- Months after the last real month have no rates (we never invent future rates).
CREATE OR REPLACE TABLE mart.dim_month AS
SELECT
    CAST(m.month AS DATE)               AS month,
    year(m.month)                       AS year,
    quarter(m.month)                    AS quarter,
    strftime(m.month, '%Y-%m')          AS month_label,
    r.policy_rate,
    r.prime_rate,
    r.goc_5yr_yield,
    r.posted_5yr_mortgage,
    -- What borrowers actually paid on a 5-yr fixed: bond yield + spread (posted rate is a sticker price)
    r.goc_5yr_yield + assumption('fixed_spread_over_goc_5yr') AS est_5yr_fixed_mortgage_rate,
    COALESCE(r.source, 'no data (future month)') AS rate_source
FROM range(DATE '2015-01-01', DATE '2028-01-01', INTERVAL 1 MONTH) AS m(month)
LEFT JOIN raw.rates AS r
    ON r.month = CAST(m.month AS DATE);


-- cba_region: how the Canadian Bankers Association groups provinces in its
-- arrears data (it reports the four Atlantic provinces together).
-- real_arrears_factor: the region's REAL 90+ arrears rate over our window,
-- divided by Canada's. Saskatchewan's mortgages fall behind far more often than
-- Quebec's, whatever their unemployment. Notebook 02 uses the same factor.
CREATE OR REPLACE TABLE mart.dim_province AS
WITH provinces AS (
    SELECT * FROM (VALUES
        ('ON', 'Ontario',                   'Central',  'Ontario'),
        ('QC', 'Quebec',                    'Central',  'Quebec'),
        ('BC', 'British Columbia',          'West',     'British Columbia'),
        ('AB', 'Alberta',                   'Prairies', 'Alberta'),
        ('MB', 'Manitoba',                  'Prairies', 'Manitoba'),
        ('SK', 'Saskatchewan',              'Prairies', 'Saskatchewan'),
        ('NS', 'Nova Scotia',               'Atlantic', 'Atlantic'),
        ('NB', 'New Brunswick',             'Atlantic', 'Atlantic'),
        ('NL', 'Newfoundland and Labrador', 'Atlantic', 'Atlantic'),
        ('PE', 'Prince Edward Island',      'Atlantic', 'Atlantic')
    ) AS t(province, province_name, region, cba_region)
),
window_arrears AS (
    SELECT region, SUM(mortgages_in_arrears) / SUM(total_mortgages) AS arrears_rate
    FROM raw.mortgage_arrears
    WHERE CAST(month AS DATE) BETWEEN (SELECT CAST(MIN(month) AS DATE) FROM raw.loan_months)
                                  AND (SELECT CAST(MAX(month) AS DATE) FROM raw.loan_months)
    GROUP BY region
)
SELECT
    p.*,
    a.arrears_rate / (SELECT arrears_rate FROM window_arrears WHERE region = 'Canada') AS real_arrears_factor
FROM provinces AS p
JOIN window_arrears AS a ON a.region = p.cba_region;

-- REAL economy by province and month (Statistics Canada). Grain: province + month.
CREATE OR REPLACE TABLE mart.fact_province_month AS
SELECT
    CAST(u.month AS DATE)   AS month,
    u.province,
    u.unemployment_rate,
    u.population_thousands,
    u.source
FROM raw.unemployment AS u
WHERE u.province <> 'CA';


CREATE OR REPLACE TABLE mart.dim_product AS
SELECT
    product,
    product_name,
    secured,
    assumption('lgd_' || product) AS loss_given_default,  -- share of a defaulted balance that is lost
    sort_order
FROM (VALUES
    ('mortgage', 'Mortgage',       'Secured',   1),
    ('heloc',    'HELOC',          'Secured',   2),
    ('auto',     'Auto loan',      'Secured',   3),
    ('card',     'Credit card',    'Unsecured', 4)
) AS t(product, product_name, secured, sort_order);


CREATE OR REPLACE TABLE mart.dim_credit_band AS
SELECT * FROM (VALUES
    ('Below 600', 300, 599, 1),
    ('600-659',   600, 659, 2),
    ('660-719',   660, 719, 3),
    ('720-779',   720, 779, 4),
    ('780+',      780, 900, 5)
) AS t(credit_band, min_score, max_score, sort_order);


-- One row per loan: who the borrower is and the loan's terms
CREATE OR REPLACE TABLE mart.dim_loan AS
SELECT
    l.loan_id,
    l.product,
    l.province,
    l.rate_type,
    l.credit_score,
    b.credit_band,
    CAST(l.origination_month AS DATE)   AS origination_month,
    year(l.origination_month)           AS vintage_year,
    l.original_balance,
    l.rate_at_signing,
    l.renews_in_window,
    l.source
FROM raw.loans AS l
JOIN mart.dim_credit_band AS b
    ON l.credit_score BETWEEN b.min_score AND b.max_score;


-- -----------------------------------------------------------------------------
-- FACT: one row per loan per month (grain: loan_id + month)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE mart.fact_loan_month AS
SELECT
    loan_id,
    CAST(month AS DATE) AS month,
    status,
    CASE status
        WHEN 'current' THEN 0  WHEN '30 dpd' THEN 1  WHEN '60 dpd' THEN 2
        WHEN '90 dpd'  THEN 3  WHEN '120 dpd' THEN 4 WHEN 'default' THEN 5
    END AS status_order,
    balance,
    delinquent_balance,      -- 30 to 120 days late
    impaired_balance,        -- 90 to 120 days late
    defaulted_balance,       -- the month the loan defaulted
    rate_increase_pp,
    source
FROM raw.loan_months;


-- -----------------------------------------------------------------------------
-- SUMMARY: portfolio by month x product x province x credit band
-- This is the main table behind the dashboard's trend and regional pages.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE mart.agg_portfolio_monthly AS
SELECT
    f.month,
    d.product,
    d.province,
    d.credit_band,
    COUNT(*)                                        AS open_loans,
    SUM(f.balance)                                  AS balance,
    SUM(f.delinquent_balance)                       AS delinquent_balance,
    SUM(f.impaired_balance)                         AS impaired_balance,
    SUM(f.defaulted_balance)                        AS defaulted_balance,
    COUNT(*) FILTER (WHERE f.status <> 'current' AND f.status <> 'default') AS delinquent_loans,
    COUNT(*) FILTER (WHERE f.status = 'default')    AS new_defaults,
    'SIMULATED - not real customers'                AS source
FROM mart.fact_loan_month AS f
JOIN mart.dim_loan AS d USING (loan_id)
GROUP BY ALL;


-- -----------------------------------------------------------------------------
-- LOAN OUTCOME: did each loan default during the window? (one row per loan)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE mart.loan_outcome AS
SELECT
    loan_id,
    MIN(month)                                       AS first_month_seen,
    MAX(month)                                       AS last_month_seen,
    MAX(CASE WHEN status = 'default' THEN 1 ELSE 0 END) AS defaulted,
    SUM(defaulted_balance)                           AS defaulted_balance
FROM mart.fact_loan_month
GROUP BY loan_id;


-- -----------------------------------------------------------------------------
-- PROBABILITY OF DEFAULT (PD) by product x credit band, measured from the data
-- -----------------------------------------------------------------------------
-- Cohort = loans already open in the first month (Apr 2023), followed for the
-- full 42 months. Banks provision on a 12-month PD, so convert:
--   12-month PD = 1 - (1 - 42-month default rate) ^ (12 / 42)
CREATE OR REPLACE TABLE mart.pd_by_segment AS
SELECT
    d.product,
    d.credit_band,
    COUNT(*)                                          AS loans_in_cohort,
    SUM(o.defaulted)                                  AS defaulted_loans,
    SUM(o.defaulted) / COUNT(*)                       AS default_rate_42m,
    1 - POWER(1 - SUM(o.defaulted) / COUNT(*), 12.0 / 42) AS pd_12m
FROM mart.dim_loan AS d
JOIN mart.loan_outcome AS o USING (loan_id)
WHERE o.first_month_seen = (SELECT MIN(month) FROM mart.fact_loan_month)
GROUP BY d.product, d.credit_band;


-- -----------------------------------------------------------------------------
-- THE MAIN ANALYSIS: one row per fixed mortgage renewing in 2025-2027
-- -----------------------------------------------------------------------------
-- Expected loss (EL) = balance x PD x LGD (loss given default).
-- PD = the credit band's measured 12-month PD x the region's real arrears factor
-- (so a Saskatchewan borrower carries more risk than an identical one in Quebec).
-- Our model says each +1pp of rate raises the chance of missing a payment by
-- `rate_increase_per_pp` (25%). So at renewal:
--   stressed PD           = PD x (1 + 0.25 x rate jump in pp)
--   incremental provision = EL with stressed PD - EL with normal PD
-- = the extra cash the bank should set aside because of the renewal.
CREATE OR REPLACE TABLE mart.fact_renewal AS
WITH renewals AS (
    SELECT
        l.loan_id,
        d.province,
        d.credit_band,
        d.credit_score,
        CAST(l.renewal_month AS DATE)             AS renewal_month,
        year(l.renewal_month)                     AS renewal_year,
        l.renewal_month <= (SELECT MAX(month) FROM mart.fact_loan_month) AS already_renewed,
        l.old_rate,
        l.new_rate,
        l.new_rate - l.old_rate                   AS rate_jump_pp,
        l.balance_at_renewal,
        l.old_payment,
        l.new_payment,
        l.payment_increase,
        l.payment_increase * 12                   AS annual_payment_increase,
        l.payment_shock_pct,
        CASE
            WHEN l.payment_shock_pct < 0  THEN 'Payment down'
            WHEN l.payment_shock_pct < 10 THEN '0-10%'
            WHEN l.payment_shock_pct <= 25 THEN '10-25%'
            ELSE 'Over 25%'   -- same cut-off as is_severe_shock / the At-Risk KPI
        END                                       AS shock_band,
        l.payment_shock_pct > assumption('severe_payment_shock_pct') AS is_severe_shock,
        o.defaulted = 1                           AS has_defaulted,
        l.new_rate_source,
        l.source
    FROM raw.loans AS l
    JOIN mart.dim_loan AS d USING (loan_id)
    LEFT JOIN mart.loan_outcome AS o USING (loan_id)
    WHERE l.renews_in_window
),
with_provision AS (
    SELECT
        r.*,
        pr.real_arrears_factor                    AS region_factor,
        p.pd_12m * pr.real_arrears_factor         AS base_pd_12m,
        LEAST(p.pd_12m * pr.real_arrears_factor * (1 + assumption('rate_increase_per_pp') * GREATEST(r.rate_jump_pp, 0)), 1)
                                                  AS stressed_pd_12m,
        assumption('lgd_mortgage')                AS loss_given_default
    FROM renewals AS r
    JOIN mart.pd_by_segment AS p
        ON p.product = 'mortgage' AND p.credit_band = r.credit_band
    JOIN mart.dim_province AS pr
        ON pr.province = r.province
),
with_loss AS (
    SELECT
        *,
        balance_at_renewal * base_pd_12m     * loss_given_default AS expected_loss_before,
        balance_at_renewal * stressed_pd_12m * loss_given_default AS expected_loss_after,
        balance_at_renewal * (stressed_pd_12m - base_pd_12m) * loss_given_default AS incremental_provision,
        -- Can still be called: hasn't renewed yet and hasn't defaulted
        NOT already_renewed AND NOT COALESCE(has_defaulted, false) AS can_contact
    FROM with_provision
)
SELECT
    *,
    -- Who to call first: biggest added loss first (only borrowers we can still reach)
    CASE WHEN can_contact
         THEN ROW_NUMBER() OVER (PARTITION BY can_contact ORDER BY incremental_provision DESC, payment_shock_pct DESC)
    END AS outreach_priority
FROM with_loss;


-- -----------------------------------------------------------------------------
-- VINTAGE: how loans signed in each year have performed, by product
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE mart.agg_vintage AS
SELECT
    d.vintage_year,
    d.product,
    COUNT(*)                     AS loans,
    SUM(d.original_balance)      AS original_balance,
    SUM(o.defaulted)             AS defaulted_loans,
    SUM(o.defaulted_balance)     AS defaulted_balance,
    'SIMULATED - not real customers' AS source
FROM mart.dim_loan AS d
JOIN mart.loan_outcome AS o USING (loan_id)
GROUP BY d.vintage_year, d.product;


-- -----------------------------------------------------------------------------
-- VALIDATION: simulated vs REAL mortgage arrears, by CBA region and month
-- -----------------------------------------------------------------------------
-- The CBA counts mortgages 3+ months (90+ days) behind. Our equivalent is a
-- mortgage in the 90 or 120 days-past-due bucket. We store COUNTS, not rates,
-- so rates can be summed correctly across regions (rate = in_arrears / mortgages).
-- Real data ends when the CBA's latest file ends, so the last months can be empty.
CREATE OR REPLACE TABLE mart.arrears_validation AS
WITH simulated AS (
    SELECT
        f.month,
        p.cba_region                                                  AS region,
        COUNT(*)                                                      AS simulated_mortgages,
        SUM(CASE WHEN f.status IN ('90 dpd', '120 dpd') THEN 1 ELSE 0 END) AS simulated_in_arrears
    FROM mart.fact_loan_month AS f
    JOIN mart.dim_loan AS d USING (loan_id)
    JOIN mart.dim_province AS p ON p.province = d.province
    WHERE d.product = 'mortgage'
    GROUP BY f.month, p.cba_region
),
with_canada AS (
    SELECT * FROM simulated
    UNION ALL
    SELECT month, 'Canada', SUM(simulated_mortgages), SUM(simulated_in_arrears)
    FROM simulated
    GROUP BY month
)
SELECT
    s.month,
    s.region,
    CAST(s.simulated_mortgages AS INTEGER)   AS simulated_mortgages,
    CAST(s.simulated_in_arrears AS INTEGER)  AS simulated_in_arrears,
    CAST(r.total_mortgages AS BIGINT)        AS real_mortgages,
    CAST(r.mortgages_in_arrears AS BIGINT)   AS real_in_arrears,
    'Simulated (ours) vs Canadian Bankers Association (real)' AS source
FROM with_canada AS s
LEFT JOIN raw.mortgage_arrears AS r
    ON CAST(r.month AS DATE) = s.month AND r.region = s.region;
