-- =============================================================================
-- 04 · Business questions, answered in SQL
-- =============================================================================
-- Each query answers one question. Notebook 03 runs them all and shows the
-- results. The README quotes numbers ONLY from these queries.
--
-- Reminder: loans are SIMULATED, interest rates are REAL.
-- Every rate below is SUM(amount) / SUM(balance) - never an average of ratios.


-- Q1. How big is the renewal wave, and how hard does it hit each year?
--     (shock is weighted by balance, so a $900k mortgage counts more than a $150k one)
SELECT
    renewal_year,
    COUNT(*)                                                     AS renewing_loans,
    CAST(SUM(already_renewed::INT) AS INTEGER)                   AS already_renewed,
    ROUND(SUM(balance_at_renewal) / 1e6, 1)                      AS renewing_balance_m,
    ROUND(SUM(payment_shock_pct * balance_at_renewal) / SUM(balance_at_renewal), 1) AS weighted_avg_shock_pct,
    ROUND(SUM(GREATEST(annual_payment_increase, 0)) / 1e6, 2)    AS added_annual_payments_m,
    ROUND(COALESCE(SUM(balance_at_renewal) FILTER (WHERE is_severe_shock), 0) / 1e6, 1) AS at_risk_balance_m
FROM mart.fact_renewal
GROUP BY renewal_year
ORDER BY renewal_year;


-- Q2. What does the shock look like? Loans and balance by shock band
SELECT
    shock_band,
    COUNT(*)                                                     AS loans,
    ROUND(SUM(balance_at_renewal) / 1e6, 1)                      AS balance_m,
    ROUND(100.0 * SUM(balance_at_renewal) / SUM(SUM(balance_at_renewal)) OVER (), 1) AS pct_of_renewing_balance,
    ROUND(AVG(payment_increase), 0)                              AS avg_monthly_increase_cad
FROM mart.fact_renewal
GROUP BY shock_band
ORDER BY MIN(payment_shock_pct);


-- Q3. Which year did the current term start? (this is what really drives the shock)
SELECT
    renewal_year - 5                                             AS term_started,
    COUNT(*)                                                     AS loans,
    ROUND(MEDIAN(old_rate), 2)                                   AS median_old_rate,
    ROUND(MEDIAN(new_rate), 2)                                   AS median_new_rate,
    ROUND(MEDIAN(payment_shock_pct), 1)                          AS median_shock_pct,
    ROUND(MEDIAN(payment_increase), 0)                           AS median_monthly_increase_cad
FROM mart.fact_renewal
GROUP BY term_started
ORDER BY term_started;


-- Q4. Which provinces carry the most renewal risk? Size (total provision) and intensity
--     (provision per $1M of balance), with the REAL drivers: arrears factor and unemployment
SELECT
    p.province_name,
    ROUND(MAX(p.real_arrears_factor), 2)                         AS real_arrears_factor,
    ROUND(AVG(u.unemployment_rate), 1)                           AS avg_unemployment_pct,
    COUNT(*)                                                     AS renewing_loans,
    ROUND(SUM(r.balance_at_renewal) / 1e6, 1)                    AS renewing_balance_m,
    ROUND(SUM(r.payment_shock_pct * r.balance_at_renewal) / SUM(r.balance_at_renewal), 1) AS weighted_avg_shock_pct,
    ROUND(SUM(r.incremental_provision), 0)                       AS incremental_provision_cad,
    ROUND(100.0 * SUM(r.incremental_provision) / SUM(SUM(r.incremental_provision)) OVER (), 1) AS pct_of_total_provision,
    ROUND(1e6 * SUM(r.incremental_provision) / SUM(r.balance_at_renewal), 0) AS provision_per_1m_balance
FROM mart.fact_renewal AS r
JOIN mart.dim_province AS p USING (province)
JOIN (SELECT province, AVG(unemployment_rate) AS unemployment_rate
      FROM mart.fact_province_month
      WHERE month BETWEEN (SELECT MIN(month) FROM mart.fact_loan_month) AND (SELECT MAX(month) FROM mart.fact_loan_month)
      GROUP BY province) AS u USING (province)
GROUP BY p.province_name
ORDER BY incremental_provision_cad DESC;

-- Q5. Does payment shock fall on weaker borrowers? Compare each credit band's share of
--     the HIGH-SHOCK group (20%+) with its share of ALL renewals. Lift > 1 = over-represented.
--     (A bare "X% of high-shock loans are subprime" means nothing without the base share.)
WITH bands AS (
    SELECT
        credit_band,
        COUNT(*)                                  AS all_renewals,
        COUNT(*) FILTER (WHERE payment_shock_pct >= 20) AS high_shock
    FROM mart.fact_renewal
    GROUP BY credit_band
)
SELECT
    b.credit_band,
    b.all_renewals,
    b.high_shock,
    ROUND(100.0 * b.all_renewals / SUM(b.all_renewals) OVER (), 1) AS pct_of_renewals,
    ROUND(100.0 * b.high_shock   / SUM(b.high_shock)   OVER (), 1) AS pct_of_high_shock,
    ROUND((b.high_shock * 1.0 / SUM(b.high_shock) OVER ())
        / (b.all_renewals * 1.0 / SUM(b.all_renewals) OVER ()), 2) AS lift
FROM bands AS b
JOIN mart.dim_credit_band AS c USING (credit_band)
ORDER BY c.sort_order;


-- Q6. Where should the extra provision be held? By credit band.
SELECT
    r.credit_band,
    COUNT(*)                                                     AS renewing_loans,
    ROUND(AVG(r.base_pd_12m) * 100, 3)                           AS base_pd_12m_pct,
    ROUND(AVG(r.stressed_pd_12m) * 100, 3)                       AS stressed_pd_12m_pct,
    ROUND(SUM(r.expected_loss_before), 0)                        AS expected_loss_before_cad,
    ROUND(SUM(r.expected_loss_after), 0)                         AS expected_loss_after_cad,
    ROUND(SUM(r.incremental_provision), 0)                       AS incremental_provision_cad
FROM mart.fact_renewal AS r
JOIN mart.dim_credit_band AS c USING (credit_band)
GROUP BY r.credit_band, c.sort_order
ORDER BY c.sort_order;


-- Q7. Headline portfolio KPIs in the latest month, by product
SELECT
    p.product_name,
    CAST(SUM(a.open_loans) AS INTEGER)                           AS open_loans,
    ROUND(SUM(a.balance) / 1e6, 1)                               AS exposure_m,
    ROUND(100.0 * SUM(a.delinquent_balance) / SUM(a.balance), 2) AS delinquency_rate_pct,
    ROUND(100.0 * SUM(a.impaired_balance)   / SUM(a.balance), 2) AS impaired_rate_pct
FROM mart.agg_portfolio_monthly AS a
JOIN mart.dim_product AS p USING (product)
WHERE a.month = (SELECT MAX(month) FROM mart.agg_portfolio_monthly)
GROUP BY p.product_name, p.sort_order
ORDER BY p.sort_order;


-- Q8. Default rates by product and credit band (the PD table behind the provision)
SELECT
    p.product_name,
    s.credit_band,
    s.loans_in_cohort,
    CAST(s.defaulted_loans AS INTEGER)                           AS defaulted_loans,
    ROUND(100 * s.default_rate_42m, 2)                           AS default_rate_42m_pct,
    ROUND(100 * s.pd_12m, 3)                                     AS pd_12m_pct
FROM mart.pd_by_segment AS s
JOIN mart.dim_product AS p USING (product)
JOIN mart.dim_credit_band AS c USING (credit_band)
ORDER BY p.sort_order, c.sort_order;


-- Q9. Did rising rates show up in HELOCs (their rate floats with prime)? HELOC delinquency vs prime, by quarter
SELECT
    m.year,
    m.quarter,
    ROUND(AVG(m.prime_rate), 2)                                  AS avg_prime_rate,
    ROUND(100.0 * SUM(a.delinquent_balance) / SUM(a.balance), 2) AS heloc_delinquency_pct
FROM mart.agg_portfolio_monthly AS a
JOIN mart.dim_month AS m USING (month)
WHERE a.product = 'heloc'
GROUP BY m.year, m.quarter
ORDER BY m.year, m.quarter;


-- Q10. Who do we call first? Top 15 borrowers who haven't renewed yet
SELECT
    r.outreach_priority,
    r.loan_id,
    p.province_name,
    r.credit_score,
    r.renewal_month,
    r.old_rate,
    r.new_rate,
    ROUND(r.payment_increase, 0)                                 AS monthly_increase_cad,
    r.payment_shock_pct,
    ROUND(r.incremental_provision, 0)                            AS incremental_provision_cad
FROM mart.fact_renewal AS r
JOIN mart.dim_province AS p USING (province)
WHERE r.outreach_priority <= 15
ORDER BY r.outreach_priority;


-- Q11. Data quality summary
SELECT
    dimension,
    COUNT(*)                                                     AS checks,
    CAST(SUM(CASE WHEN result = 'PASS' THEN 1 ELSE 0 END) AS INTEGER) AS passed,
    CAST(SUM(CASE WHEN result = 'FAIL' THEN 1 ELSE 0 END) AS INTEGER) AS failed
FROM quality.check_results
GROUP BY dimension
ORDER BY dimension;


-- Q12. Headline numbers (the KPI cards on the dashboard, and the README summary)
SELECT
    (SELECT ROUND(SUM(balance) / 1e9, 2) FROM mart.agg_portfolio_monthly
      WHERE month = (SELECT MAX(month) FROM mart.agg_portfolio_monthly))          AS total_exposure_bn,
    (SELECT ROUND(100.0 * SUM(delinquent_balance) / SUM(balance), 2) FROM mart.agg_portfolio_monthly
      WHERE month = (SELECT MAX(month) FROM mart.agg_portfolio_monthly))          AS delinquency_rate_pct,
    (SELECT ROUND(100.0 * SUM(impaired_balance) / SUM(balance), 2) FROM mart.agg_portfolio_monthly
      WHERE month = (SELECT MAX(month) FROM mart.agg_portfolio_monthly))          AS impaired_rate_pct,
    COUNT(*)                                                                     AS renewing_mortgages,
    ROUND(SUM(balance_at_renewal) / 1e9, 2)                                      AS renewing_balance_bn,
    ROUND(SUM(payment_shock_pct * balance_at_renewal) / SUM(balance_at_renewal), 1) AS weighted_avg_shock_pct,
    ROUND(SUM(balance_at_renewal) FILTER (WHERE is_severe_shock) / 1e6, 1)       AS at_risk_balance_m,
    ROUND(SUM(GREATEST(annual_payment_increase, 0)) / 1e6, 1)                    AS added_annual_payments_m,
    ROUND(SUM(incremental_provision), 0)                                         AS incremental_provision_cad,
    CAST(SUM(CASE WHEN outreach_priority IS NOT NULL THEN 1 ELSE 0 END) AS INTEGER) AS borrowers_still_to_call
FROM mart.fact_renewal;


-- Q13. Does the simulation match REAL mortgage arrears by region?
--      Real = Canadian Bankers Association (90+ days late). Skips the first 3 months:
--      every simulated loan starts "current", so nothing can be 90+ days late until month 4.
WITH window_months AS (
    SELECT month FROM mart.arrears_validation
    WHERE region = 'Canada'
      AND real_mortgages IS NOT NULL
      AND month >= (SELECT MIN(month) FROM mart.fact_loan_month) + INTERVAL 3 MONTH
),
by_region AS (
    SELECT
        region,
        100.0 * SUM(real_in_arrears) / SUM(real_mortgages)           AS real_arrears_pct,
        100.0 * SUM(simulated_in_arrears) / SUM(simulated_mortgages) AS simulated_arrears_pct
    FROM mart.arrears_validation
    WHERE month IN (SELECT month FROM window_months) AND region <> 'Canada'
    GROUP BY region
),
unemployment AS (
    -- population-weighted, so Atlantic Canada isn't a plain average of four provinces
    SELECT p.cba_region AS region,
           SUM(u.unemployment_rate * u.population_thousands) / SUM(u.population_thousands) AS unemployment_pct
    FROM mart.fact_province_month AS u
    JOIN mart.dim_province AS p USING (province)
    WHERE u.month IN (SELECT month FROM window_months)
    GROUP BY p.cba_region
)
SELECT
    b.region,
    ROUND(u.unemployment_pct, 1)                                   AS real_unemployment_pct,
    ROUND(b.real_arrears_pct, 3)                                   AS real_arrears_pct,
    ROUND(b.simulated_arrears_pct, 3)                              AS simulated_arrears_pct,
    RANK() OVER (ORDER BY b.real_arrears_pct DESC)                 AS real_rank,
    RANK() OVER (ORDER BY b.simulated_arrears_pct DESC)            AS simulated_rank
FROM by_region AS b
JOIN unemployment AS u USING (region)
ORDER BY real_rank;


-- Q14. Does the simulation follow the REAL national arrears trend? By quarter.
SELECT
    year(month)                                                   AS year,
    quarter(month)                                                AS quarter,
    ROUND(100.0 * SUM(real_in_arrears) / SUM(real_mortgages), 3)  AS real_arrears_pct,
    ROUND(100.0 * SUM(simulated_in_arrears) / SUM(simulated_mortgages), 3) AS simulated_arrears_pct
FROM mart.arrears_validation
WHERE region = 'Canada'
  AND real_mortgages IS NOT NULL
  AND month >= (SELECT MIN(month) FROM mart.fact_loan_month) + INTERVAL 3 MONTH
GROUP BY year, quarter
ORDER BY year, quarter;


-- Q15. Validation in one row: how closely do simulated and real arrears move together?
--      corr() = correlation: +1 move together perfectly, 0 unrelated, -1 opposite.
--      The last two columns compare REAL with REAL: does real unemployment explain real
--      arrears over time (nationally), and across regions?
WITH national AS (
    SELECT
        v.month,
        100.0 * v.real_in_arrears / v.real_mortgages               AS real_pct,
        100.0 * v.simulated_in_arrears / v.simulated_mortgages     AS simulated_pct,
        u.unemployment_rate                                        AS unemployment_pct
    FROM mart.arrears_validation AS v
    JOIN raw.unemployment AS u ON CAST(u.month AS DATE) = v.month AND u.province = 'CA'
    WHERE v.region = 'Canada'
      AND v.real_mortgages IS NOT NULL
      AND v.month >= (SELECT MIN(month) FROM mart.fact_loan_month) + INTERVAL 3 MONTH
),
quarterly AS (
    SELECT year(month) AS y, quarter(month) AS q, AVG(real_pct) AS real_pct, AVG(simulated_pct) AS simulated_pct
    FROM national
    GROUP BY y, q
),
regions AS (
    SELECT
        p.cba_region,
        AVG(u.unemployment_rate)                                   AS unemployment_pct,
        AVG(100.0 * r.arrears_rate)                                AS real_pct
    FROM raw.mortgage_arrears AS r
    JOIN mart.dim_province AS p ON p.cba_region = r.region
    JOIN mart.fact_province_month AS u ON u.province = p.province AND u.month = CAST(r.month AS DATE)
    WHERE CAST(r.month AS DATE) IN (SELECT month FROM national)
    GROUP BY p.cba_region
)
SELECT
    (SELECT COUNT(*) FROM national)                                AS months_compared,
    (SELECT ROUND(AVG(real_pct), 3) FROM national)                 AS real_avg_arrears_pct,
    (SELECT ROUND(AVG(simulated_pct), 3) FROM national)            AS simulated_avg_arrears_pct,
    (SELECT ROUND(AVG(simulated_pct) / AVG(real_pct), 2) FROM national) AS simulated_to_real_ratio,
    (SELECT ROUND(corr(real_pct, simulated_pct), 2) FROM national) AS sim_vs_real_monthly_corr,
    (SELECT ROUND(corr(real_pct, simulated_pct), 2) FROM quarterly) AS sim_vs_real_quarterly_corr,
    (SELECT ROUND(corr(real_pct, unemployment_pct), 2) FROM national) AS real_arrears_vs_unemployment_over_time,
    (SELECT ROUND(corr(real_pct, unemployment_pct), 2) FROM regions)  AS real_arrears_vs_unemployment_across_regions;