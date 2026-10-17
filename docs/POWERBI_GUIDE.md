# Power BI build guide

Everything you need to build the dashboard from the CSVs in `powerbi/data/`.
Every expected number below comes from **Q12 / Q1–Q10 in `notebooks/03_build_warehouse.ipynb`**,
so you can check each visual against the SQL as you build.

> **Provenance rule:** the loan data is **simulated**; the interest rates are **real** (Bank of
> Canada). Every page must say so (step 6 below).

---

## 1. Load the data

`Home → Get Data → Text/CSV`, one file at a time (or `Get Data → Folder` → `powerbi/data` →
*Combine & Transform* is **not** wanted here — load each file as its own table).

| Table | Rows | What it is |
| --- | --- | --- |
| `dim_month` | 156 | One row per month, Jan 2015 – Dec 2027, with the **real** rates |
| `dim_province` | 10 | Province code, name, region |
| `dim_product` | 4 | Product name, secured/unsecured, loss given default |
| `dim_credit_band` | 5 | Credit score bands with a sort order |
| `agg_portfolio_monthly` | 8,361 | Balances by month × product × province × credit band |
| `fact_renewal` | 6,716 | One row per fixed mortgage renewing in 2025–27 (the main analysis) |
| `agg_vintage` | 46 | Loans and defaults by signing year × product |
| `pd_by_segment` | 20 | Default rates by product × credit band |
| `data_quality_checks` | 18 | The 18 data-quality checks and their results |

**Check data types in Power Query** before closing:

- `month`, `renewal_month` → **Date**
- `balance`, `*_balance`, `payment_*`, `expected_loss_*`, `incremental_provision` → **Fixed decimal number** (currency)
- `*_rate`, `*_pct`, `pd_*`, `rate_jump_pp` → **Decimal number**
- `already_renewed`, `is_severe_shock`, `has_defaulted`, `can_contact` → **True/False**
- `outreach_priority` → **Whole number** (blank for borrowers we can't call)

## 2. Relationships (Model view)

Star schema: dimensions on the outside, facts in the middle. All **one-to-many, single direction**
(dimension filters fact).

| From (one side) | To (many side) |
| --- | --- |
| `dim_month[month]` | `agg_portfolio_monthly[month]` |
| `dim_month[month]` | `fact_renewal[renewal_month]` |
| `dim_province[province]` | `agg_portfolio_monthly[province]` |
| `dim_province[province]` | `fact_renewal[province]` |
| `dim_product[product]` | `agg_portfolio_monthly[product]` |
| `dim_product[product]` | `fact_renewal[product]` |
| `dim_product[product]` | `agg_vintage[product]` |
| `dim_product[product]` | `pd_by_segment[product]` |
| `dim_credit_band[credit_band]` | `agg_portfolio_monthly[credit_band]` |
| `dim_credit_band[credit_band]` | `fact_renewal[credit_band]` |
| `dim_credit_band[credit_band]` | `pd_by_segment[credit_band]` |

`data_quality_checks` stands alone.

**Sort-by-column** (Column tools → Sort by column), so bands don't sort alphabetically:

- `dim_credit_band[credit_band]` → by `sort_order`
- `dim_product[product_name]` → by `sort_order`
- `dim_month[month_label]` → by `month`

**Hide** the key columns on the fact tables (`month`, `product`, `province`, `credit_band`) so
report builders always use the dimension versions.

## 3. Measures (DAX)

Create a blank table called `_Measures` (Enter Data → one empty column) and put every measure in
it. **Every rate is a `DIVIDE` of two `SUM`s** — never `AVERAGE` a ratio column, or a $5k card
counts as much as a $900k mortgage.

### Portfolio

```dax
Exposure = SUM ( agg_portfolio_monthly[balance] )

Latest Month = MAX ( agg_portfolio_monthly[month] )

Exposure (Latest Month) =
VAR LatestMonth = [Latest Month]
RETURN CALCULATE ( [Exposure], dim_month[month] = LatestMonth )

Delinquency Rate =
DIVIDE ( SUM ( agg_portfolio_monthly[delinquent_balance] ), SUM ( agg_portfolio_monthly[balance] ) )

Delinquency Rate (Latest Month) =
VAR LatestMonth = [Latest Month]
RETURN CALCULATE ( [Delinquency Rate], dim_month[month] = LatestMonth )

Impaired Rate =
DIVIDE ( SUM ( agg_portfolio_monthly[impaired_balance] ), SUM ( agg_portfolio_monthly[balance] ) )

Impaired Rate (Latest Month) =
VAR LatestMonth = [Latest Month]
RETURN CALCULATE ( [Impaired Rate], dim_month[month] = LatestMonth )

Open Loans (Latest Month) =
VAR LatestMonth = [Latest Month]
RETURN CALCULATE ( SUM ( agg_portfolio_monthly[open_loans] ), dim_month[month] = LatestMonth )

New Defaults = SUM ( agg_portfolio_monthly[new_defaults] )
```

### Renewal wave (the headline analysis)

```dax
Renewing Mortgages = COUNTROWS ( fact_renewal )

Renewing Balance = SUM ( fact_renewal[balance_at_renewal] )

At-Risk Exposure =
CALCULATE ( [Renewing Balance], fact_renewal[is_severe_shock] = TRUE () )

At-Risk Share = DIVIDE ( [At-Risk Exposure], [Renewing Balance] )

Added Annual Payment Burden =
SUMX (
    FILTER ( fact_renewal, fact_renewal[annual_payment_increase] > 0 ),
    fact_renewal[annual_payment_increase]
)

-- Weighted by balance: a $700k mortgage moves this more than a $150k one
Avg Payment Shock % =
DIVIDE (
    SUMX ( fact_renewal, fact_renewal[payment_shock_pct] * fact_renewal[balance_at_renewal] ),
    [Renewing Balance]
)

Median Monthly Increase = MEDIAN ( fact_renewal[payment_increase] )

Already Renewed % =
DIVIDE ( CALCULATE ( [Renewing Mortgages], fact_renewal[already_renewed] = TRUE () ), [Renewing Mortgages] )

Incremental Provision = SUM ( fact_renewal[incremental_provision] )

Expected Loss Before = SUM ( fact_renewal[expected_loss_before] )

Expected Loss After = SUM ( fact_renewal[expected_loss_after] )

Borrowers To Call =
CALCULATE ( [Renewing Mortgages], fact_renewal[can_contact] = TRUE () )
```

### Risk / vintage

```dax
Vintage Default Rate =
DIVIDE ( SUM ( agg_vintage[defaulted_loans] ), SUM ( agg_vintage[loans] ) )

Default Rate 42m =
DIVIDE ( SUM ( pd_by_segment[defaulted_loans] ), SUM ( pd_by_segment[loans_in_cohort] ) )

Avg Prime Rate = AVERAGE ( dim_month[prime_rate] )

Avg Est Fixed Mortgage Rate = AVERAGE ( dim_month[est_5yr_fixed_mortgage_rate] )
```

### Data quality and provenance

```dax
Checks Run = COUNTROWS ( data_quality_checks )

Checks Passed = CALCULATE ( [Checks Run], data_quality_checks[result] = "PASS" )

Checks Failed = CALCULATE ( [Checks Run], data_quality_checks[result] = "FAIL" ) + 0

Last Checked = MAX ( data_quality_checks[checked_at] )

-- Lists every source in the current filter (never MIN/MAX a text column for this)
Loan Data Source =
CONCATENATEX ( VALUES ( agg_portfolio_monthly[source] ), agg_portfolio_monthly[source], ", " )

Provenance Banner =
"Loan data: SIMULATED (not real customers)  |  Interest rates: Bank of Canada Valet API (real)  |  Rates after "
    & FORMAT ( CALCULATE ( MAX ( dim_month[month] ), dim_month[policy_rate] <> BLANK () ), "mmm yyyy" )
    & " held flat (assumption)"
```

**Formats:** exposure/balances → currency, 0 decimals, display units Millions or Billions;
rates and shares → percentage, 2 decimals; `Avg Payment Shock %` → it's already in percent
units, so use a decimal with 1 decimal place and add "%" in the title.

## 4. Pages and visuals

Six pages. Put the same three **slicers** on pages 1–4 and sync them (View → Sync slicers):
`dim_province[province_name]`, `dim_product[product_name]`, `dim_credit_band[credit_band]`.

### Page 1 — Executive summary

The five KPI cards (five is the limit; a sixth means you haven't decided what matters):

| Card | Measure | Expected (no filters) |
| --- | --- | --- |
| Total Exposure | `Exposure (Latest Month)` | **$8.41B** |
| Delinquency Rate | `Delinquency Rate (Latest Month)` | **0.53%** |
| Impaired Rate (90+ days) | `Impaired Rate (Latest Month)` | **0.09%** |
| At-Risk Exposure (shock > 25%) | `At-Risk Exposure` | **$244.9M** |
| Added Annual Payment Burden | `Added Annual Payment Burden` | **$28.3M** |

Below the cards:

- **Clustered column chart — "The renewal wave"**: X = `dim_month[month]` (2025–2027),
  Y = `Renewing Balance`, Legend = `fact_renewal[already_renewed]`. Expected yearly totals:
  2025 $852.8M · 2026 $900.8M · 2027 $950.0M.
- **Line chart — "Real rates, 2015–2026"**: X = `dim_month[month]`, Y = `Avg Prime Rate` and
  `Avg Est Fixed Mortgage Rate`. Add a shaded band or annotation for Mar 2020 – Feb 2022 (low-rate era).
- **Text box / card** with `Provenance Banner` across the top or bottom.

### Page 2 — Renewal cliff

- **Cards:** `Renewing Mortgages` (6,716), `Renewing Balance` ($2.70B), `Avg Payment Shock %`
  (15.2), `Median Monthly Increase`, `Already Renewed %`.
- **Column chart:** X = `fact_renewal[renewal_year]`, Y = `Avg Payment Shock %`.
  Expected: 2025 19.8 · 2026 20.2 · 2027 6.3.
- **Bar chart:** X = `fact_renewal[shock_band]`, Y = `Renewing Balance`.
  Expected: 0-10% $726.5M · 10-25% $1,732.3M · Over 25% $244.9M.
- **Scatter chart:** X = `old_rate`, Y = `new_rate`, Details = `loan_id`, Size = `balance_at_renewal`,
  Legend = `renewal_year`. Points far above the diagonal are the shock.
- **Insight title:** "Terms locked in 2020–21 at ~2% renew at ~4.2–4.6%: a ~20% higher payment."

### Page 3 — Where the risk sits (province × credit band)

- **Filled map** (or shape map): Location = `dim_province[province_name]`, colour saturation =
  `Incremental Provision`. (Turn on map visuals in Options → Security if blocked.)
- **Matrix:** Rows = `province_name`, Columns = `credit_band`, Values = `Incremental Provision`,
  with **conditional formatting → background colour**. Expected total $193,428; largest cell
  Ontario × 660-719.
- **Bar chart:** `credit_band` vs `Expected Loss Before` and `Expected Loss After` (clustered).
- **Honesty note (text box):** "Provinces are assigned at random in the simulation, so regional
  differences reflect where balances are, not regional economic stress."

### Page 4 — Portfolio performance

- **Line chart:** X = `dim_month[month]`, Y = `Delinquency Rate`, Legend = `dim_product[product_name]`.
- **Line and column chart:** X = `dim_month[month]`; columns = `Delinquency Rate` filtered to
  HELOC (visual-level filter product_name = HELOC); line = `Avg Prime Rate`.
  Title: "HELOC delinquency follows prime".
- **Matrix heatmap:** Rows = `product_name`, Columns = `credit_band`, Values = `Default Rate 42m`,
  conditional formatting. Expected: card × Below 600 ≈ 12.66%, mortgage × 780+ ≈ 0.24%.
- **Column chart:** X = `agg_vintage[vintage_year]`, Y = `Vintage Default Rate`, Legend = product.

### Page 5 — Outreach call list

- **Cards:** `Borrowers To Call` (2,797), `Incremental Provision`.
- **Table:** filter `outreach_priority` is not blank and ≤ 100 (visual-level filter, "Top N"
  also works). Columns: `outreach_priority`, `loan_id`, `province_name`, `credit_score`,
  `renewal_month`, `old_rate`, `new_rate`, `payment_increase`, `payment_shock_pct`,
  `incremental_provision`. Sort by `outreach_priority` ascending.
  Expected row 1: loan 30258, Alberta, score 586, renews Oct 2026, 2.83% → 5.14%.
- **Slicer:** `renewal_month` (between), so the team can work month by month.

### Page 6 — Data quality

Almost nobody includes this page; it's the cheapest way to show you think about data like a bank does.

- **Cards:** `Checks Run` (18), `Checks Passed` (18), `Checks Failed` (0), `Last Checked`.
- **Table:** `dimension`, `check_name`, `severity`, `failed_rows`, `result`, with conditional
  formatting on `result` (PASS green, FAIL red).
- **Donut or bar:** checks by `dimension` (completeness 3, uniqueness 3, validity 5,
  consistency 4, reconciliation 3).
- **Text box:** the provenance banner, plus "Simulated loan book generated with a fixed seed —
  re-running the pipeline reproduces every number."

## 5. Design checklist

- One accent colour for "risk" (e.g. dark red) used only for bad things; neutral greys elsewhere.
- Titles say the insight, not the chart type ("HELOC delinquency follows prime", not "Line chart").
- Same number formats everywhere ($M with 1 decimal, rates with 2 decimals).
- Every page footer: the `Provenance Banner`.
- Don't add: average interest rate across all products (averages a 5% mortgage with a 20% card),
  borrower count as a KPI (exposure is the risk measure), average credit score, or a
  "portfolio health score" (a composite nobody can decompose).

## 6. Before you publish — verify

With no slicers selected, your cards must match **Q12** in notebook 03:

| Measure | Q12 value |
| --- | --- |
| Exposure (Latest Month) | 8.41 bn |
| Delinquency Rate (Latest Month) | 0.53% |
| Impaired Rate (Latest Month) | 0.09% |
| Renewing Mortgages | 6,716 |
| Renewing Balance | 2.70 bn |
| Avg Payment Shock % | 15.2 |
| At-Risk Exposure | 244.9 M |
| Added Annual Payment Burden | 28.3 M |
| Incremental Provision | 193,428 |
| Borrowers To Call | 2,797 |

If a card is off, the usual cause is a wrong relationship or a measure using `AVERAGE` on a ratio.
