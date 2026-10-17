-- =============================================================================
-- 05 · Export the tables Power BI needs to CSV
-- =============================================================================
-- Power BI imports these CSVs (Get Data -> Text/CSV), so the report opens
-- without DuckDB installed. All small: the 1.7M-row fact table is summarised
-- into agg_portfolio_monthly first.

-- Dimensions (the filters / slicers)
COPY mart.dim_month       TO 'powerbi/data/dim_month.csv'       (HEADER);
COPY mart.dim_province    TO 'powerbi/data/dim_province.csv'    (HEADER);
COPY mart.dim_product     TO 'powerbi/data/dim_product.csv'     (HEADER);
COPY mart.dim_credit_band TO 'powerbi/data/dim_credit_band.csv' (HEADER);

-- Facts (the numbers)
COPY mart.agg_portfolio_monthly TO 'powerbi/data/agg_portfolio_monthly.csv' (HEADER);
COPY mart.agg_vintage           TO 'powerbi/data/agg_vintage.csv'           (HEADER);
COPY mart.pd_by_segment         TO 'powerbi/data/pd_by_segment.csv'         (HEADER);
COPY (SELECT 'mortgage' AS product, * FROM mart.fact_renewal)
                                TO 'powerbi/data/fact_renewal.csv'          (HEADER);

-- Real provincial data + validation (simulated vs real arrears)
COPY mart.fact_province_month TO 'powerbi/data/fact_province_month.csv' (HEADER);
COPY mart.arrears_validation  TO 'powerbi/data/arrears_validation.csv'  (HEADER);

-- Data quality page
COPY quality.check_results TO 'powerbi/data/data_quality_checks.csv' (HEADER);
