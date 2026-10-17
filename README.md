# Canadian Mortgage Renewal Risk Analytics

**Which borrowers get hit hardest when Canada's low-rate mortgages renew in 2025–2027, how much
extra provision does that imply, and who should the bank call first?**

SQL (DuckDB) · Python (pandas, numpy, matplotlib, seaborn, scikit-learn) · Power BI · real Bank of Canada data

> **Data honesty:** interest rates are **real** (Bank of Canada Valet API). The loan book is
> **simulated** — no Canadian lender publishes customer-level loan data — and every simulated row
> is labelled `SIMULATED - not real customers`. Findings about the loan book describe this
> simulated portfolio, built to behave like a Canadian retail book; they are not claims about real
> borrowers.

![Real Canadian rates](images/01_real_rates.png)

---

## The business problem

A Canadian mortgage is paid off over **25 years**, but its rate is only locked for **5**. Families
who locked in at ~2% in 2020–21 must renew at whatever rates are then — and they can't refuse.
(In the US a 30-year mortgage locks the rate for all 30 years; this problem is specifically Canadian.)

The bank needs to know, *before* it happens:

1. **Which** mortgages renew, and **when**?
2. **How much** does each monthly payment go up (the *payment shock*)?
3. **Who** is likely to struggle?
4. **How much** extra cash (provision) to set aside?
5. **Who** to call first?

## Key findings

All numbers come from the SQL queries in [`sql/04_analysis_queries.sql`](sql/04_analysis_queries.sql)
(results in [`notebooks/03_build_warehouse.ipynb`](notebooks/03_build_warehouse.ipynb)). Query names in brackets.

| | |
| --- | --- |
| Renewing fixed mortgages, 2025–27 | **6,716** loans, **$2.70B** balance [Q12] |
| Balance-weighted payment shock | **+15.2%** overall; **+19.8%** in 2025, **+20.2%** in 2026, **+6.3%** in 2027 [Q1, Q12] |
| At-risk exposure (shock > 25%) | **$244.9M**, 9.1% of renewing balance [Q2, Q12] |
| Added payments for households | **$28.3M a year** across the book [Q12] |
| Extra provision implied | **$193,428** [Q12] |
| Borrowers still reachable before renewal | **2,797** [Q12] |

1. **The shock is about *timing*, not the borrower.** Terms locked in 2020 at a median **1.82%**
   renew at **4.20%** (+19.1%, about **$405/month**); 2021 terms go **2.28% → 4.56%** (+20.2%,
   **$450/month**). Terms locked in 2022 started at **4.38%**, so their shock is only +4.2% [Q3].
2. **Every credit band is hit about equally.** Each band's share of the high-shock group is within
   0.86–1.02× its share of all renewals (lift ≈ 1) [Q5]. The *risk* is where a big shock meets a
   weak credit score.
3. **So the provision concentrates in weaker credit.** A "Below 600" borrower's 12-month default
   probability rises from **0.55% to 0.79%** with the renewal shock; the 660–719 band holds the most
   extra provision overall (**$67,473**) because it has the most loans [Q6].
4. **No one in the 2025–27 wave gets cheaper**, if rates stay where they are: rates peaked in late
   2022 at about today's level. Loans signed in 2023–24 will reprice *cheaper* — in 2028–29.
5. **Rate rises show up in variable-rate debt.** As prime rose to 7.2%, HELOC delinquency rose from
   **0.65% to a peak of 0.97%** (Q4 2023), then eased as prime fell [Q9].
6. **Call list:** the top of the list is sub-600 borrowers renewing Oct 2026 – Feb 2027 with a
   ~2pp rate jump and $470–875 more per month [Q10].

![Renewal calendar](images/02_renewal_calendar.png)
![Payment shock](images/03_payment_shock_distribution.png)

## How it works

```text
Bank of Canada Valet API (real rates)
        │  src/fetch_rates.py
        ▼
data/rates.csv ──► 01_simulate_loans.ipynb ──► data/loans.csv           (50,000 loans, SIMULATED)
                   02_simulate_performance ──► data/loan_months.parquet (1.69M loan-months, SIMULATED)
        │
        ▼  03_build_warehouse.ipynb runs the sql/ files
DuckDB warehouse
  raw.*      source files loaded unchanged                     sql/01_load_raw.sql
  mart.*     star schema + renewal / provision analysis         sql/02_build_tables.sql
  quality.*  18 data-quality checks — the build STOPS on error  sql/03_quality_checks.sql
             business questions Q1–Q12                          sql/04_analysis_queries.sql
        │                                                       sql/05_export_powerbi.sql
        ▼
powerbi/data/*.csv ──► Power BI dashboard (guide: docs/POWERBI_GUIDE.md)
        │
        ├──► 04_analysis_and_charts.ipynb  (pandas + seaborn charts → images/)
        └──► 05_default_risk_model.ipynb   (logistic regression)
```

**How the simulation uses real data:** every loan is priced off the real rate in the month it was
signed (fixed mortgage = 5-year Government of Canada bond yield + 1.40pp; variable = prime − 1.00).
Each month, a current loan can miss a payment; a late loan either catches up or falls further
behind (current → 30 → 60 → 90 → 120 days → default). The chance of missing a payment goes up
when the loan's real rate has gone up since signing, and for lower credit scores. Every tunable
number is in [`config/pipeline.yml`](config/pipeline.yml), tagged `[brief]` (researched) or
`[ASSUMPTION]` (a judgement call).

### Star schema

| Table | Grain | Type |
| --- | --- | --- |
| `dim_month` | one month (real rates attached) | dimension |
| `dim_province`, `dim_product`, `dim_credit_band` | one value | dimension |
| `dim_loan` | one loan | dimension |
| `fact_loan_month` | one loan × one month | fact |
| `fact_renewal` | one renewing fixed mortgage | fact — the main analysis |
| `agg_portfolio_monthly` | month × product × province × credit band | summary for Power BI |
| `pd_by_segment`, `agg_vintage` | product × credit band / signing year × product | summary |

Amounts are stored, never ratios (`delinquent_balance`, not `delinquency_rate`): rates are
computed as `SUM(...) / SUM(...)` so they stay correct under any filter.

### Data quality

18 checks across **completeness, uniqueness, validity, consistency and reconciliation** (e.g.
"one row per loan per month", "no loan appears after it defaulted", "total balance in the
warehouse ties to the source file within 0.01%"). An error-level failure stops the build before
anything reaches the dashboard. Current result: **18 of 18 pass** [Q11]. The results are exported
to a data-quality page in Power BI.

### Default-risk model

A logistic regression (scikit-learn) predicts default from credit score, product, loan size, the
loan's rate increase, and time on book. On a held-out 30% test set: **AUC 0.758**, and the riskiest
20% of loans by the model contain **51%** of all defaults
([notebook 05](notebooks/05_default_risk_model.ipynb)). Because the data is simulated, the model is
used to check the workflow: it recovers the built-in credit-score effect (odds ratio 0.42 per 100
points vs 0.5 designed).

![Default heatmap](images/07_default_heatmap.png)

## Problems found and fixed along the way

These are documented in the notebooks because finding them is the analyst's job:

- **Correlated random numbers.** Both simulations first used the same seed, so month-1 "missed
  payment" draws were the same numbers that had chosen each loan's product: mortgages missed
  payments ~3× too often and credit cards never did. Caught by checking month-1 delinquency by
  product; fixed with a separate seed.
- **Data leakage in the model.** A "months observed" feature was shorter for defaulted loans
  (they leave the book), so the model learned "fewer months → more default". It scored a better
  AUC (0.84) for the wrong reason. Replaced with months the loan *could* be observed.
- **Non-reproducible model.** DuckDB returned rows in a different order each run, so the
  train/test split changed. Fixed with `ORDER BY loan_id`.
- **Undercounted 2025 renewals.** Starting loans in 2016 left out 2015 signings, which renew
  for the second time in 2025. Fixed by starting in 2015.
- **Posted vs actual mortgage rates.** The Bank of Canada "conventional 5-year" rate is a sticker
  price (4.79% in Jan 2021) that banks discount heavily; borrowers actually paid ~1.8–1.9%. The
  project uses bond yield + spread instead.

## Limitations

- The loan book is simulated, so **regional findings reflect where balances are, not regional
  stress** — provinces are assigned at random and there is no regional economy in the model.
  Adding Statistics Canada unemployment by province is the natural next step.
- Renewals after Sep 2026 use the last real rate held flat — a stated assumption, not a forecast.
- Mortgage default counts per credit band are small (6–25 defaults), so band-level PDs are noisy.
- HELOC and card balances are held flat over time (a simplification).

## Run it yourself

Windows, Python 3.12:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python src\fetch_rates.py      # real rates from the Bank of Canada
```

Then open the notebooks in VS Code (or Jupyter) and **Run All** in order: `01` → `02` → `03` →
`04` → `05`. The SQL files in `sql/` can also be read and run on their own against
`data/warehouse.duckdb`. Every run is logged to `logs/pipeline.log`. The simulation is seeded, so
re-running reproduces every number above.

## Repository

```text
config/pipeline.yml      every tunable number, with its source
src/fetch_rates.py       downloads the real rates
src/logger.py            logging to screen + logs/pipeline.log
notebooks/               01-05: simulate → warehouse → analysis → model
sql/                     01-05: load → build → quality checks → questions → export
powerbi/data/            CSVs for the Power BI report
docs/POWERBI_GUIDE.md    dashboard build guide: model, DAX measures, pages, expected values
docs/PROJECT-BRIEF.md    background research: Canadian job market, domain explainer
images/                  charts used in this README
```
