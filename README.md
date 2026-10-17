# Canadian Mortgage Renewal Risk Analytics

**Which borrowers get hit hardest when Canada's low-rate mortgages renew in 2025–2027, how much
extra provision does that imply, and who should the bank call first?**

SQL (DuckDB) · Python (pandas, numpy, matplotlib, seaborn, scikit-learn) · Power BI ·
real Bank of Canada, Statistics Canada and Canadian Bankers Association data

> **Data honesty:** three sources are **real**: interest rates (Bank of Canada), unemployment by
> province (Statistics Canada), and mortgage arrears by region (Canadian Bankers Association). The
> loan book is **simulated**, because no Canadian lender publishes customer-level data. It is driven
> by the real data and then **checked against it** (see *Validation*). Every simulated row is labelled
> `SIMULATED - not real customers`. Findings about the loan book describe this simulated portfolio,
> not real borrowers.

![Real Canadian rates](images/01_real_rates.png)

---

## The business problem

A Canadian mortgage is paid off over **25 years**, but its rate is only locked for **5**. Families
who locked in at ~2% in 2020–21 must renew at whatever rates are then, and they can't refuse.
(In the US a 30-year mortgage locks the rate for all 30 years, so this problem is specifically Canadian.)

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
| Extra provision implied | **$211,222** [Q12] |
| Borrowers still reachable before renewal | **2,797** [Q12] |

1. **The shock is about *timing*, not the borrower.** Terms locked in 2020 at a median **1.82%**
   renew at **4.20%** (+19.1%, about **$405/month**); 2021 terms go **2.28% → 4.56%** (+20.2%,
   **$450/month**). Terms locked in 2022 started at **4.38%**, so their shock is only +4.2% [Q3].
   Every credit band is hit about equally (lift 0.86–1.02) [Q5].
2. **The risk is where the shock meets weak credit.** Mortgage default rates fall from **1.91%**
   below a 600 credit score to **0.28%** at 780+ [Q8]. A "Below 600" borrower's 12-month default
   probability rises from **0.55% to 0.79%** with the renewal shock [Q6].
3. **Where you live matters, but not because of unemployment.** Real arrears data shows
   Saskatchewan's mortgages fall 90+ days behind **2.58×** as often as Canada's, while Quebec's
   are at **0.78×**. So the extra provision per $1M of renewing balance is **$213 in Saskatchewan**
   vs **$63 in Quebec** [Q4]. Ontario still holds the most in total (38.8%) because it's the biggest.
   Real unemployment tracks arrears **over time** (correlation 0.69) but **not across regions** (−0.29) [Q15].
4. **No one in the 2025–27 wave gets cheaper**, if rates stay where they are: rates peaked in late
   2022 at about today's level. Loans signed in 2023–24 will reprice *cheaper*, in 2028–29.
5. **Rate rises showed up in variable-rate debt.** As prime rose to 7.2%, HELOC delinquency rose
   from **0.48% to a peak of 0.88%** (Q1 2024), then eased as prime fell [Q9].
6. **Call list:** the top 3 are in **Alberta and Saskatchewan** (high real arrears); the top 15 all have
   credit scores of 640 or below and renew Oct 2026 – Mar 2027, most with a ~2pp rate jump [Q10].

![Renewal calendar](images/02_renewal_calendar.png)
![Provision intensity by province](images/12_provision_intensity_by_province.png)

## Validation against real data

The simulation is **driven** by one real source and **checked** against another, so the check
isn't circular.

| Check | Result |
| --- | --- |
| Real arrears vs real unemployment, over time | correlation **0.69**: unemployment explains *when* stress rises [Q15] |
| Real arrears vs real unemployment, across regions | correlation **−0.29**: it doesn't explain *where* [Q15] |
| Simulated vs real national arrears trend (quarterly) | correlation **0.41**: follows the rise, loosely [Q14, Q15] |
| Simulated vs real arrears level | simulated is **0.41×** real (0.089% vs 0.219%) [Q15] |
| Regional ranking | matches for 5 of 7 regions, **by calibration, not a test** [Q13] |

**Why the level is lower:** a real mortgage can stay 90+ days behind for many months while the
bank goes through the legal process to sell the home; the model writes a loan off after 120 days,
so fewer loans sit "in arrears" at any moment. Matching it would mean modelling foreclosure
timelines, which is out of scope, so the gap is reported rather than tuned away.

![Simulated vs real arrears](images/11_real_vs_simulated_arrears.png)

## How it works

```text
Bank of Canada Valet API (rates)        src/fetch_rates.py
Statistics Canada (unemployment)   ┐
Canadian Bankers Assoc. (arrears)  ┘    src/fetch_provincial_data.py
        │  all REAL
        ▼
01_simulate_loans.ipynb ──► data/loans.csv            50,000 loans, SIMULATED
                            (province mix from real mortgage counts)
02_simulate_performance ──► data/loan_months.parquet  1.69M loan-months, SIMULATED
                            (risk driven by real rates, unemployment, regional arrears)
        │
        ▼  03_build_warehouse.ipynb runs the sql/ files
DuckDB warehouse
  raw.*      source files loaded unchanged                     sql/01_load_raw.sql
  mart.*     star schema + renewal / provision + validation     sql/02_build_tables.sql
  quality.*  23 data-quality checks; the build STOPS on error   sql/03_quality_checks.sql
             business questions Q1–Q12, validation Q13–Q15      sql/04_analysis_queries.sql
        │                                                       sql/05_export_powerbi.sql
        ▼
powerbi/data/*.csv ──► Power BI dashboard (guide: docs/POWERBI_GUIDE.md)
        ├──► 04_analysis_and_charts.ipynb  (pandas + seaborn charts → images/)
        └──► 05_default_risk_model.ipynb   (logistic regression)
```

**How the simulation uses real data:**

- Every loan is priced off the real rate in the month it was signed (fixed mortgage = 5-year
  Government of Canada bond yield + 1.40pp; variable = prime − 1.00).
- Each month, a current loan can miss a payment, and a late loan either catches up or falls further
  behind (current → 30 → 60 → 90 → 120 days → default).
- The chance of missing a payment rises with:
  - the loan's **real rate increase** since signing
  - its region's **real arrears level** (CBA)
  - **real unemployment** that month (StatCan)
  - a **lower credit score**

Every tunable number is in [`config/pipeline.yml`](config/pipeline.yml), tagged `[brief]`
(researched) or `[ASSUMPTION]` (a judgement call).

### Star schema

| Table | Grain | Type |
| --- | --- | --- |
| `dim_month` | one month (real rates attached) | dimension |
| `dim_province` | one province (real arrears factor attached) | dimension |
| `dim_product`, `dim_credit_band` | one value | dimension |
| `dim_loan` | one loan | dimension |
| `fact_loan_month` | one loan × one month | fact |
| `fact_renewal` | one renewing fixed mortgage | fact (the main analysis) |
| `fact_province_month` | one province × one month (real unemployment) | fact, REAL |
| `arrears_validation` | one region × one month (simulated vs real counts) | fact |
| `agg_portfolio_monthly` | month × product × province × credit band | summary for Power BI |
| `pd_by_segment`, `agg_vintage` | product × credit band / signing year × product | summary |

Amounts are stored, never ratios (`delinquent_balance`, not `delinquency_rate`): rates are
computed as `SUM(...) / SUM(...)` so they stay correct under any filter.

### Data quality

23 checks across **completeness, uniqueness, validity, consistency and reconciliation**, on both
the simulated and the real data. Examples:

- one row per loan per month
- no loan appears after it defaulted
- total balance ties to the source file within 0.01%
- unemployment exists for every province in every month
- the CBA's regions add up to its Canada total

An error-level failure stops the build before anything reaches the dashboard. Current result:
**23 of 23 pass** [Q11].

### Default-risk model

A logistic regression (scikit-learn) predicts default from credit score, product, loan size, rate
increase, time on book and the real regional arrears factor. On a held-out 30% test set it scores
**AUC 0.770**, and the riskiest 20% of loans by the model contain **55%** of all defaults
([notebook 05](notebooks/05_default_risk_model.ipynb)). Because the loans are simulated, the model
checks the workflow: it recovers the built-in rules (credit-score odds ratio 0.44 per 100 points vs
0.5 designed; regional-factor coefficient 1.13 vs 1 designed).

## Problems found and fixed along the way

- **Correlated random numbers.** Both simulations first used the same seed, so month-1 "missed
  payment" draws were the same numbers that had chosen each loan's product. Mortgages missed payments
  ~3× too often and credit cards never did. Caught by checking month-1 delinquency by product.
- **Data leakage in the model.** A "months observed" feature was shorter for defaulted loans (they
  leave the book), so the model learned "fewer months → more default" and scored a flattering AUC
  (0.84). Replaced with months the loan *could* be observed.
- **Non-reproducible model.** DuckDB returned rows in a different order each run, so the
  train/test split changed. Fixed with `ORDER BY loan_id`.
- **Undercounted 2025 renewals.** Starting loans in 2016 left out 2015 signings, which renew for the
  second time in 2025.
- **Posted vs actual mortgage rates.** The Bank of Canada "conventional 5-year" rate is a sticker
  price (4.79% in Jan 2021); borrowers actually paid ~1.8–1.9%. The project uses bond yield + spread.
- **Unemployment doesn't explain regional arrears.** The first real-data version drove regional risk
  with unemployment; checking it against real arrears showed the regional ranking was wrong
  (Saskatchewan has low unemployment but the highest arrears). The model now uses unemployment for
  *timing* and real arrears for *location*.
- **Real data has a lag.** The CBA's file ends two months before our window; the pipeline keeps what
  exists, never fills gaps, and logs a warning.

## Limitations

- The loan book is simulated, so findings describe this portfolio, not real borrowers.
- The simulated arrears level is ~0.4× the real level (see *Validation*).
- Regional risk factors are calibrated to real arrears, so the regional match is not evidence of
  accuracy; only the time trend is a genuine test.
- Renewals after Sep 2026 use the last real rate held flat (a stated assumption, not a forecast).
- Mortgage default counts per credit band are small (7–26 defaults), so band-level PDs are noisy.
- HELOC and card balances are held flat over time (a simplification).

## Run it yourself

Windows, Python 3.12:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python src\fetch_rates.py            # Bank of Canada rates
.venv\Scripts\python src\fetch_provincial_data.py  # StatCan unemployment + CBA arrears
```

Then open the notebooks in VS Code (or Jupyter) and **Run All** in order: `01` → `02` → `03` →
`04` → `05`. The SQL files in `sql/` can also be read and run on their own against
`data/warehouse.duckdb`. Every run is logged to `logs/pipeline.log`. The simulation is seeded, so
re-running reproduces every number above. The CBA file name includes its month; when a newer file
is published, update the URL in `config/pipeline.yml`.

## Repository

```text
config/pipeline.yml          every tunable number, with its source
src/fetch_rates.py           real Bank of Canada rates
src/fetch_provincial_data.py real StatCan unemployment + CBA mortgage arrears
src/logger.py                logging to screen + logs/pipeline.log
notebooks/                   01-05: simulate → warehouse → analysis → model
sql/                         01-05: load → build → quality checks → questions → export
powerbi/data/                CSVs for the Power BI report
docs/POWERBI_GUIDE.md        dashboard build guide: model, DAX measures, pages, expected values
docs/PROJECT_EXPLAINED.md    the whole project explained from scratch
docs/PROJECT-BRIEF.md        background research: Canadian job market, domain explainer
images/                      charts used in this README
```
