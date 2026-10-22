# Canadian Credit Risk Dashboard: Power BI Project

The dashboard from `docs/POWERBI_GUIDE.md`, built as a Power BI Project (PBIP): a TMDL semantic model and a 7-page PBIR report, loading the 11 CSVs in `data/`.

## Open it

1. The model reads the CSVs from the repo's `powerbi\data\` folder
   (`C:\dev\canadian-credit-risk-analytics\powerbi\data\`). If your copy of the repo lives
   somewhere else, go to **Transform data > Manage parameters > DataFolder** and set the full path,
   ending in `\`.
2. Power BI Desktop: **Options > Preview features**, tick **Power BI Project (.pbip) save option** and
   **Store reports using enhanced metadata format (PBIR)** if they aren't already on. Restart.
3. Open `CreditRiskDashboard.pbip` and click **Refresh** (needed after any change to the CSVs or the
   model, including the `renewal_status` column added below).

## Verify against Q12 (guide section 6)

With no slicers selected, the cards should match. Each value below was recomputed from the CSVs before the report was built.

| Measure | Expected |
| --- | --- |
| Exposure (Latest Month) | $8.40bn |
| Delinquency Rate (Latest Month) | 0.58% |
| Impaired Rate (Latest Month) | 0.10% |
| Renewing Mortgages | 6,716 |
| Renewing Balance | $2.70bn |
| Avg Payment Shock % | 15.2 |
| At-Risk Exposure | $244.9M |
| Added Annual Payment Burden | $28.3M |
| Incremental Provision | $211,222 |
| Borrowers To Call | 2,797 |

More spot checks:
- Renewal years: 2025 $852.8M / 19.8, 2026 $900.8M / 20.2, 2027 $950.0M / 6.3.
- Shock bands: 0-10% $726.5M, 10-25% $1,732.3M, Over 25% $244.9M.
- Provision per $1M: Saskatchewan $213, Quebec $63.
- Matrix peak: Ontario x 660-719 = $28,364.
- Default Rate 42m: card x Below 600 = 12.66%, mortgage x 780+ = 0.28%.
- Call list row 1: loan 30258, Alberta, score 586, Oct 2026, 2.83% to 5.14%.
- Reality check (Canada, Jul 2023 onward): real 0.219%, simulated 0.090%, ratio 0.41.
- Data quality: 23 run, 23 passed, 0 failed.

## What's in the model

- 11 tables loaded exactly as listed in guide section 1, with types pinned per the guide: dates, fixed decimal (currency), whole numbers, true/false. Blank cells load as null, so unpublished CBA months stay blank instead of erroring.
- 14 one-to-many, single-direction relationships from guide section 2. Fact keys are hidden; the three sort-by-column rules are applied.
- `_Measures` holds every measure from guide section 3, verbatim, in five display folders. These helpers were added:
  - `Old Rate` / `New Rate` (one point per loan on the scatter).
  - `Real Arrears Factor` (colours the risk-per-dollar bars).
  - `Result Colour` (PASS green, FAIL red).
  - `Checks Failed` returns 0, not blank.
  - `Unemployment Rate (Analysis Window)`: unemployment over Apr 2023 - Sep 2026 only, so page 3 matches Q4.
- `fact_renewal[renewal_status]`: a calculated column ("Already renewed" / "Still to renew") so the page 1 legend reads in words, not True / False.

## Pages

1. Executive summary
2. Renewal cliff
3. Where the risk sits
4. Portfolio performance
5. Outreach call list
6. Reality check
7. Data quality

Pages 1-4 share three synced slicers (province, product, credit band). Every page carries the `Provenance Banner` as its footer.

## Differences from the guide

- **No filled map on page 3.** Map visuals depend on a Desktop security setting and tenant policy. The bar chart, matrix and table carry the same information. Add a map in Desktop if you want one.
- **No shaded low-rate band on the rates chart.** The chart title names the Mar 2020 - Feb 2022 window instead. You can add the shading in Desktop with an X-axis constant line or error bars.
- **Page 6 uses one page-level filter** (month on or after 1 Jul 2023) instead of the same visual-level filter repeated on every visual. The numbers are identical.

## Fixes after checking the first build

The first version was checked page by page against the SQL results (Q1-Q15). Everything matched except:

| Issue | Fix |
| --- | --- |
| Renewing balance card showed **$3bn** (real: $2.70bn); exposure showed $8bn | Cards set to 2 decimals in billions, 1 decimal in millions |
| Page 3 unemployment averaged **every month since 2015** (Newfoundland 12.2) instead of the analysis window (9.8, as in Q4) | New measure `Unemployment Rate (Analysis Window)` |
| Page 1 legend read **True / False** | `renewal_status` column with plain words |
| Page 2 scatter bubbles were sized by balance and overlapped into blobs | Size field removed: one even dot per mortgage |

The project was first generated with scripts; it is now edited directly (in Power BI Desktop or as text),
so the scripts are not part of the repo.
