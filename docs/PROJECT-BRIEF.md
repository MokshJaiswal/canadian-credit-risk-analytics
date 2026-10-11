# Canadian Credit Risk Analytics — project brief

**A complete, self-contained brief for building this project from scratch.**

Research conducted October 2026 against live Canadian job postings. Everything
in Part 1 is evidence; everything after it is a design decision that follows
from that evidence.

---

## How to use this file

1. Create a new GitHub repo, e.g. `canadian-credit-risk-analytics`.
2. Clone it, drop this file in as `docs/PROJECT-BRIEF.md`, commit, push.
3. Open the folder in VS Code (as the workspace root).
4. Create a working branch: `git checkout -b build/pipeline`
5. Open Claude Code and paste:

> Read `docs/PROJECT-BRIEF.md` end to end. It is the complete specification for
> this project — market research, business problem, architecture, build plan,
> code standards, and a list of bugs a previous attempt hit so we don't repeat
> them. Then start at **Part 4, Step 0**. Follow the working style in Part 5:
> one file at a time, stop after each so I can run it, and tell me the exact
> command plus what I should expect to see. I'm on Windows. Don't read ahead or
> build out of order.

That's it. Work conversationally from there.

---

# PART 1 — Market research (the evidence)

Primary evidence: live Indeed Canada postings sampled across Toronto, Vancouver
and Calgary in October 2026, **read in full rather than by title.** Full
descriptions read for Moneris, SureWerx, Scotiabank, RBC and Fidelity Canada.

## 1.1 The single most important finding: title is the wrong search term

Searching `"Data Analyst"` in Toronto surfaced roughly as many postings under
*other* titles as under that one. In a sample of ~40 postings:

| Title family | Example employers |
|---|---|
| Data Analyst | Scotiabank, Reach3 Insights, FOUR20, TD (co-op) |
| Business / Business Data Analyst | Moneris, First National Financial, EQ Bank |
| Business Systems Analyst | TD, isgSearch |
| Business Intelligence Analyst / Developer | Atlantic Packaging, SRX Health, Raise |
| Reporting / Advanced Analytics Analyst | Fidelity Canada |
| Domain analyst (Pricing, Supply Chain, FP&A, Procurement, Logistics) | Sysco, SmartCentres, BCAA |
| Data Warehouse Analyst | TransLink |

**Implication:** searching only "Data Analyst" sees perhaps half the addressable
market. The skills are near-identical across all of these. **Search on the work,
not the label.**

## 1.2 Which sectors carry entry-level volume

Ranked by observed posting density:

1. **Financial services** — the deepest pool by a wide margin, concentrated in
   Toronto. Banks (TD, RBC, Scotiabank, BMO, CIBC, EQ Bank), payments (Moneris),
   asset management (Fidelity Canada), mortgage finance (First National).
2. **Healthcare / pharma** — Sanofi, SRX Health, Canadian Cancer Society.
3. **Retail, CPG, distribution** — Sysco, SureWerx, Atlantic Packaging.
4. **Public sector / crown corps** — City of Calgary, TransLink, BDC. Slower
   cycles, but they publish salary bands and interview predictably.
5. **Consulting / staffing** — isgSearch, Raise, VIMY. Fastest route to a first
   title, at the cost of stability.

## 1.3 What the postings actually require

### Universal — in essentially every posting
- **SQL** — writing *and optimising* queries, creating views, complex extraction
  and transformation. Not just `SELECT ... WHERE`.
- **A BI tool — Power BI dominates in Canada**, especially finance and
  enterprise. Tableau appears as "Tableau or Power BI". Canadian enterprise is
  overwhelmingly a Microsoft shop.
- **Excel** — still explicitly listed, including by Fidelity ("advanced
  proficiency with Microsoft Excel, Access and PowerPoint").
- **Stakeholder communication** — every single posting.

### Very common, and where almost every candidate portfolio is silent
- **Data quality, validation, reconciliation.** Scotiabank devotes three
  separate responsibility blocks to it: *"monitor data quality, identify
  anomalies, investigate discrepancies"*; *"perform reconciliation activities to
  ensure completeness and accuracy between source and target systems."* Moneris:
  *"ensure data quality through data profiling, validation, and analysis of data
  from multiple sources."*
- **Requirements gathering and documentation.** SureWerx: *"assist in
  documenting requirements from business stakeholders."* Moneris: *"gather,
  document, and translate data and reporting requirements."*
- **UAT and release process.** SureWerx: *"develop test plans and conduct
  quality assurance testing prior to release"*; *"coordinate user acceptance
  testing."* Scotiabank: *"support UAT, parallel runs, production readiness."*
- **Process automation.** Scotiabank: *"identify opportunities to streamline and
  automate operational processes."*
- **Data modelling / warehousing.** Moneris: *"build and support data models,
  reporting datasets."* Scotiabank: *"data modeling, and database design."*

### The 2026 differentiators — new, and rare in candidate portfolios
- **dbt and Snowflake.** Moneris lists *"minimum 1 year of experience with dbt
  and Snowflake"* as a **required** skill on a business data analyst posting.
- **Microsoft Fabric and Copilot.** SureWerx requires *"Power BI, SQL, Copilot,
  MS Fabric, Excel"* for a **0–2 years** junior role, and asks them to *"assist
  in rollout of AI tools to accelerate reporting and analysis cycle."*
- **Data governance and lineage.** Scotiabank lists *"data lineage, metadata
  repositories, and governance frameworks."*

### Python's real position
Python is listed almost everywhere, but **read where it sits.** Scotiabank files
it under *Nice-to-Have*, beside SAS and VBA. Fidelity wants it for modelling.
RBC's co-op lists it in must-haves.

> **SQL and Power BI get you screened in. Python differentiates you once you're
> in the room.** A portfolio that is Python-heavy and SQL-light is optimised for
> the wrong filter.

## 1.4 Experience requirements, and how to read them

| Employer | Stated requirement | Reality |
|---|---|---|
| SureWerx (Junior Data Analyst) | 0–2 years | Genuinely open to entry level |
| **Scotiabank (Data Analyst)** | 3 years, **but explicitly accepts** "work, internships, co-op placements, **or academic projects**" | **A strong project counts as qualifying evidence. Build toward this posting.** |
| Moneris (Business Data Analyst) | 3–5 yrs + 1 yr dbt/Snowflake | Stretch; apply anyway if the portfolio carries dbt |
| Fidelity (Analyst, Advanced Analytics) | 2–3 years | Stretch |
| TD / RBC / BMO / Scotiabank co-ops | **Must be an enrolled student returning to school** | **Hard eligibility gate. If you have graduated, skip these entirely.** |

## 1.5 Compensation observed

| Role | Band | Source |
|---|---|---|
| Business Data Analyst, Moneris (contract) | $71,000–$100,000 | Stated in the posting |
| Analyst, Advanced Analytics, Fidelity | $75,000–$95,000 + bonus + RRSP | Stated in the posting |
| Banking data analyst, Toronto (all levels) | $26.84–$43.59/hr, median $37.62 | ZipRecruiter aggregate |

Ontario pay-transparency rules mean more postings state the band. Use posted
bands, not aggregator averages, when negotiating.

## 1.6 The gap this project exists to close

| Employers repeatedly ask for | Typical portfolio shows | Gap |
|---|---|---|
| Optimised SQL over a modelled warehouse | A notebook over a Kaggle CSV | **Large** |
| Power BI dashboards for stakeholders | A matplotlib chart grid | **Large** |
| Data quality, validation, reconciliation | Nothing | **Total** |
| Requirements documentation, UAT | Nothing | **Total** |
| Scheduled, automated pipelines | A script run once by hand | **Large** |
| dbt / modern transformation tooling | Nothing | **Total** |
| Dimensional modelling | One flat table | **Large** |
| Financial services domain knowledge | Titanic / e-commerce data | **Large** |

**Every row of that table is a build requirement below.**

---

# PART 2 — The project

## 2.1 The business question

> Between 2025 and 2027, a large share of Canadian mortgages written during the
> low-rate era reach the end of their fixed term and reprice at prevailing
> rates. For our retail book: **which segments, products and regions carry the
> greatest payment-shock and default risk, how much incremental provision does
> that imply, and where should proactive retention outreach be targeted first?**

Chosen because it is real (the dominant Canadian retail credit topic), money-
denominated (the answer is a provision figure and a target list), defensible in
an interview, and aimed at the deepest hiring sector in Canada.

## 2.2 The problem in plain English — learn to say this

You buy a house for $600,000. You have $100,000 saved. You borrow **$500,000**.

Two numbers now matter, and almost everyone confuses them:

| | How long | Called |
|---|---|---|
| How long you take to pay the loan off | **25 years** | amortization |
| How long your interest rate is locked | **5 years** | the *term* |

**Those are different numbers. That gap is the entire project.**

**You are renting money.** The "rent" is the interest rate, but the rental
agreement lasts only 5 years even though you need the money for 25. When it
ends you must sign a new agreement at whatever the rent is then. You can't
refuse. You still owe the money.

> In the US this doesn't happen — a 30-year American mortgage locks the rate for
> all 30 years. **Canada is structurally different, and that is the only reason
> this project exists.** Saying this in an interview signals you know the market.

What rates actually did (verified from the Bank of Canada API):

```
2020 – early 2022   policy 0.25%   →  homebuyers paid ~1.9%
2023 – 2024         policy 5.00%   →  ~6%
October 2026        policy 2.25%   →  ~5%   (came down, not all the way)
```

One family, signed 2021 and renewing 2026 — **$500k, 25-yr amortization:**

```
signed at 1.9%   →  $2,095/month
renews at ~5.0%  →  $2,759/month
                    ───────────────
                    +$664/month, +$7,968/year
```

Same house. Same loan. Nothing about them changed. The rent on money changed.
That increase is **payment shock**.

Multiply by hundreds of thousands of customers who signed at different times
with agreements ending on different dates. Most absorb it. Some cut back.
**Some stop paying.** And banks are legally required to set aside cash in
advance for losses they expect — too little and the regulator objects, too much
and you've idled money you could have lent.

So the bank needs to know, before it happens:
1. **Which** customers' agreements end, and **when**?
2. **How much** does each payment go up?
3. **Who** is likely to struggle?
4. **How much cash** to set aside?
5. **Who do we phone first?**

## 2.3 Jargon translation table

| What they say | What it means |
|---|---|
| Term | How long the rate is locked (5 years in Canada) |
| Amortization | How long to pay off the whole loan (25 years) |
| Renewal | Signing a new rate agreement when the term ends |
| Payment shock | How much more the monthly payment becomes at renewal |
| Exposure | Total money currently lent out |
| The book / portfolio | All of a bank's loans collectively |
| Delinquent / in arrears | Behind on payments |
| DPD (days past due) | How many days late, in 30-day buckets |
| Impaired / 90+ | 90+ days late; the bank now doubts repayment |
| Default | The bank has stopped expecting normal repayment |
| PD (probability of default) | Chance this customer stops paying |
| LGD (loss given default) | Of money owed, the fraction actually lost |
| Expected loss | owed × chance of not paying × fraction lost |
| Provision | Cash set aside in advance for expected losses |
| LTV (loan to value) | Loan ÷ house value |
| TDS (total debt service) | Share of income going to debt payments |
| Prime / subprime | Strong / weaker credit history |
| Vintage or cohort | The year a loan was signed |
| Secured / unsecured | Backed by a seizable asset (house, car) or not (card) |
| Basis point (bp) | One hundredth of 1%. 475bp = 4.75% |
| Roll rate | Chance a late customer gets later rather than catching up |
| Cure | A late customer catching back up |

---

# PART 3 — Architecture and the reasoning behind each choice

```
Bank of Canada Valet API ─┐
Statistics Canada WDS ────┤──► ingest ──► macro.parquet (provenance-stamped)
                          │                     │
   seeded simulator ──────┴──────────► macro-driven hazard model
                                              │
                              borrowers / accounts / account_month
                                              ▼
                                   Postgres (or DuckDB) — landing schema
                                              │
                        ┌─────────── data quality gate (fails the build)
                                              ▼
                            dbt: staging views → marts star schema + tests
                                              │
                                ┌─────────────┴─────────────┐
                                ▼                           ▼
                     Parquet / CSV extracts          Streamlit dashboard
                                ▼
                         Power BI report
```

| Choice | Why |
|---|---|
| **Postgres** primary, DuckDB fallback | Postings say "relational database systems" constantly; DuckDB essentially never. Keep DuckDB as a zero-setup path so a reviewer can clone and run |
| **dbt** | Moneris requires it outright on an analyst role. Gives version-controlled SQL, tests, and a lineage graph |
| **Power BI** | Dominant in Canadian financial services |
| **Streamlit** too | So a recruiter without a Power BI licence can still see the work |
| **Import mode** in Power BI, not DirectQuery | The `.pbix` must open without your database running |
| **Simulated loan book** | No lender publishes account-level performance. Banks do exactly this themselves for model development, for the same privacy reason |
| **Real macro data** | This is what makes the simulation meaningful — the portfolio responds to the actual rate path |
| **ELT, not ETL** | Load raw, transform in the warehouse with SQL. Version-controlled, testable, with lineage |
| **No Power BI Dataflows** | Transformation already lives in dbt. Two places to define "delinquent" guarantees drift. Learn Power Query M separately — it's the right tool when there's no warehouse at all |
| **No data lakehouse** | For a *data analyst* role it's architectural theatre at this data size. Relevant for a data engineer role, not this one |

## Data sources

| Source | What | Access |
|---|---|---|
| Bank of Canada Valet | policy rate, prime, 5-yr GoC yield, posted mortgage rate | Public, keyless JSON: `https://www.bankofcanada.ca/valet/observations/{series}/json?start_date=&end_date=` |
| Statistics Canada WDS | unemployment by province, CPI, New Housing Price Index | Public, keyless: `getFullTableDownloadCSV/{productId}/en` returns a zip URL |

**Series IDs that work** (verified): `V39079` policy rate · `V80691311` prime ·
`BD.CDN.5YR.DQ.YLD` 5-year GoC yield · `V80691335` posted conventional 5-year.

StatCan product IDs: `14100287` labour force · `18100004` CPI ·
`18100205` NHPI · `38100238` household debt-to-income.

---

# PART 4 — Build plan

## Step 0 — environment
Python **3.11 or 3.12** (dbt lags newer releases). Create `.venv`, install
`pandas numpy pyarrow duckdb requests PyYAML dbt-core dbt-duckdb dbt-postgres
psycopg2-binary sqlalchemy streamlit plotly black`. Write a bootstrap script
that **verifies each import and smoke-tests the config loader** — a green run
should mean the project works, not that pip exited 0. Add `.vscode/settings.json`
(interpreter, `src` on the analysis path, `PYTHONPATH` in terminals),
`launch.json` (F5 per stage) and `tasks.json`.

## Step 1 — config
One `config/pipeline.yml` holding **every** tunable: window dates, source URLs
and series IDs, portfolio size and product mix, regional shares, risk
coefficients, quality thresholds. A `load_config()` that reads it and a
`validate_config()` that fails fast on: product mix not summing to 1.0, regional
shares not summing to 1.0, start date after end date, risk sections missing a
product. **Quote the province codes in the YAML** — see Part 6.

## Step 2 — ingest
API clients for Valet and WDS with retry and exponential backoff. A macro
orchestrator with **source tiers**: live API → committed real-data snapshot →
labelled synthetic scenario. Stamp every row with a `source` column and write a
manifest recording which tier supplied each metric. Output: one tidy Parquet,
grain **one row per (month, geo, metric)**.

## Step 3 — simulate
Three tables: `borrowers`, `accounts`, `account_month`. Seeded so runs are
byte-identical. The monthly default hazard must be a **function of the ingested
macro data** — that's what makes it analysis rather than invention. Use a
**roll-rate state machine**: `CURRENT → 30 → 60 → 90 → 120 → DEFAULT`, where
current accounts *enter* delinquency at the hazard rate and delinquent accounts
either *cure* or *roll forward*. Calibrate 42-month cumulative default against
published Canadian norms: mortgage ~0.5%, HELOC ~0.8%, auto ~3%, card ~5%.

## Step 4 — warehouse
Load the Parquet into a `landing` schema **verbatim, with zero transformation**.
If landing is a faithful copy you can always re-derive downstream; transform on
the way in and a bug means re-fetching from an API that may have changed.

## Step 5 — data quality gate
Rules across five dimensions: completeness, uniqueness, validity, consistency
(referential integrity), **reconciliation** (totals tie between source and
target within a tolerance). `error` severity exits non-zero and stops the build
before the marts. Persist results to a table so quality is itself a time series.
**This is the single most under-built thing in candidate portfolios and
Scotiabank asks for it three separate times.**

## Step 6 — dbt star schema
`staging` as **views** (thin renames, always fresh), `marts` as **tables** (read
constantly by Power BI). Models: `dim_date` (conformed, monthly),
`dim_borrower`, `dim_account`, `dim_product`, `dim_geography`,
`fact_account_month` (grain: **one account, one month**), `agg_portfolio_monthly`,
and `agg_renewal_exposure` — **the last one is the actual analysis.** Add tests:
unique, not_null, relationships, accepted_values, range checks, and a composite
grain test on the fact.

**Store additive numerators, never ratios.** `delinquent_balance_cad` not
`delinquency_rate` — ratios become DAX measures so they stay correct under every
filter.

## Step 7 — export + Power BI
Export each mart to Parquet and CSV. Then build the report: five executive KPI
cards, a renewal-cliff page, a regional page, a vintage-performance page, and a
**data quality page** (almost nobody includes one; it's the cheapest way to
signal you think about data like a bank does).

## Step 8 — automation + docs
GitHub Actions running the pipeline monthly. Then write: a business requirements
document with a UAT test plan, a data dictionary **generated from
`information_schema`** so it can't drift, and a runbook.

## Step 9 — the lender-rate scraper
No Canadian lender publishes a rate API, so this is a legitimate scrape. Goal:
posted 5-year fixed rates by lender, enabling per-lender repricing and flagging
borrowers who'd save by switching. **Check `robots.txt` and ToS first;
rate-limit; cache raw HTML to disk so a parser fix doesn't need a re-scrape;
store raw separately from parsed.**

**Decide before writing it:** what is the grain of the output table, and what
should happen if the scraper runs twice on the same day? (Those are the same
decision. Think it through rather than letting the model choose.)

---

# PART 5 — Code standards and working style

## Analyst-level code — the hard rule

The owner is a data analyst who must be able to **explain every line in an
interview.** Code they can't explain is worse than simpler code they can.

**WRITE:** plain functions taking and returning DataFrames · pandas/numpy
idioms · dicts and DataFrames for data · type hints on signatures · short
docstrings saying *why* · SQL for anything set-based.

**DO NOT WRITE:** `@dataclass` · `@property` accessors over dict lookups ·
`@contextmanager` · custom exception class hierarchies (use `ValueError`,
`FileNotFoundError`) · abstract base classes · factories · dependency injection ·
`from __future__ import annotations` unless genuinely needed.

**The test:** if explaining a construct would take more than a sentence,
simplify it. This does **not** excuse correctness bugs, missing tests, or
undocumented magic numbers.

Note that heavy pandas/numpy code is *fine* — that's analyst-native. The
over-engineering risk is in the plumbing, not the analysis.

## Two rules about numbers

1. **Never state a figure the code didn't produce.** If a doc claims a number, a
   query must back it. An unverifiable number in a README is worse than no
   number, because an interviewer will ask how you got it.
2. **Never present the simulated loan book as real.** Macro data is real and
   carries a `source` column; the loan book is generated. Keep provenance
   tracked and surfaced on the dashboard itself.

## Working style

One file at a time. Stop after each so the owner can run it. Before changing
anything, say in two or three lines what you're about to do and why. After each
change, give the exact command and what to expect. No ten-file diffs.

---

# PART 6 — Traps already discovered (don't repeat these)

A previous attempt hit all of these. They cost real debugging time.

### 1. YAML reads bare `ON` as boolean `true`
YAML 1.1 parses unquoted `ON`, `OFF`, `YES`, `NO` as booleans. An Ontario
province key written `ON:` becomes `True`. **Quote province codes:** `"ON":`.
Add a config validation that checks all region keys are strings.

### 2. The published mortgage rate is the POSTED rate, not what people pay
Bank of Canada series `V80691335` ("conventional mortgage, 5-year") is a
**sticker price banks discount heavily off:**

| | Posted 5-yr | GoC 5-yr yield | GoC + 1.40 | Actually transacted |
|---|---|---|---|---|
| Jan 2021 | 4.79% | 0.43% | **1.83%** | ~1.9% ✓ |
| Oct 2026 | 6.19% | 3.60% | **5.00%** | ~5% ✓ |

**Derive the discounted rate as 5-year GoC bond yield + ~1.40pp**, with the
spread in config. Also: **fixed mortgages track bond yields; variable mortgages
track prime.** Conflating them is a common error.

### 3. A naive roll-rate machine produces almost no defaults
If you require a fresh hazard draw to advance an *already delinquent* account,
accounts sit at 30 DPD forever and defaults never materialise. Correct form:
current accounts **enter** at the hazard rate; delinquent accounts **cure** at
the cure rate or **roll forward** otherwise.

### 4. Don't give every product the same credit-score pricing sensitivity
Secured mortgages barely price on credit score above the qualifying threshold
(banks compete on headline rate); card APRs vary enormously. A flat
`-0.9pp per 100 points` gave an 800-score mortgage borrower a 1.8pp discount,
drove 2021 mortgages into a **0.9% floor that never existed in the market**, and
**inflated the headline payment-shock number by ~26%.** Use product-specific
sensitivity (~0.15 per 100 points on mortgages, ~5.5 on cards) and
product-specific rate floors at the real cycle troughs (fixed never below
~1.35%; deeply discounted variable reached ~0.95%).

### 5. `dbt.type_float()` is 4-byte FLOAT in DuckDB
It stores `1.477` as `1.4769999980926514` and dashboards display that. **Cast
money and rates to `double precision`.**

### 6. DuckDB SQL is not Postgres SQL
Building against both surfaces: `cast(x as double)` (Postgres needs
`double precision`), `unnest(generate_series(...))` date spines, `strftime`
(Postgres needs `to_char`), `QUALIFY` (Postgres rejects it), and
`round(float, 2)` (Postgres only has `round(numeric, 2)`). **Isolate dialect
differences in one macro file branching on `target.type`.** "Adapter-portable"
is a hypothesis until you've run it on the second engine.

### 7. Never `min()` a string column to report provenance
It silently picks whichever value sorts first. Use `string_agg(distinct ...)`.

### 8. Mismatched grain fans out silently
Joining `dim_account` to `fact_account_month` and summing
`original_balance_cad` overstated the loan book **38×** ($19.6B → $734.7B).
Valid SQL, no error, plausible-looking number. **You can only SUM a column at
the grain it was measured at.**

### 9. Trace one value end to end — it's how bugs 4 and 5 were found
Pick a single number and follow it from the source API through every layer to
the dashboard KPI. Aggregates hide bugs; one traced row exposes them.

---

# PART 7 — KPI definitions

Five executive cards. Five is the limit; a sixth means you haven't decided what
matters.

| KPI | Formula | Direction |
|---|---|---|
| **Total Exposure** | `SUM(balance_cad)`, current month | neutral — it's the denominator |
| **Delinquency Rate** | `DIVIDE(SUM(delinquent_balance_cad), SUM(balance_cad))` | lower better |
| **Impaired Rate** | `DIVIDE(SUM(impaired_balance_cad), SUM(balance_cad))` | lower better |
| **At-Risk Exposure** | renewing balance with projected shock > 25% | **the headline — doesn't exist in current reporting** |
| **Added Annual Payment Burden** | `SUM(payment_increase_cad) * 12`, positives only | lower better |

**Every rate is a `DIVIDE` of two `SUM`s.** If the delinquency rate were a
stored column, `AVERAGE` of it would be an average-of-ratios — wrong the moment
anyone slices by province, because it weights a $50k account the same as a $900k
one.

**Exposure-weight the payment shock**, don't plain-average it:
```dax
Avg Payment Shock =
DIVIDE(
    SUMX(agg_renewal_exposure,
         agg_renewal_exposure[projected_payment_shock_pct]
       * agg_renewal_exposure[balance_cad]),
    SUM(agg_renewal_exposure[balance_cad]))
```
A plain `AVERAGE` lets a $15k HELOC move the number as much as a $700k mortgage.
This is the most common KPI bug in credit dashboards.

## KPIs to deliberately exclude

| Rejected | Why |
|---|---|
| Average interest rate across all products | Averages a 5% mortgage with a 22% card |
| Total borrower count | Vanity. Exposure is the risk measure |
| Average credit score | Composition shifts swamp real change; use band distributions |
| "Portfolio health score" | A composite nobody can decompose when it moves |

That last one is worth saying in an interview: composite indices feel
sophisticated and are operationally useless.

## Sanity checks your results must satisfy

Exact figures depend on your seed and calibration, so **don't inherit numbers
from anyone — regenerate and verify.** But these orderings must hold:

- Secured lending defaults least, unsecured revolving most (mortgage < HELOC <
  auto < credit card). If cards look safer than mortgages, something is joined
  wrong.
- Some accounts reprice **cheaper** — those originated during the high-rate
  window. A dashboard showing only pain misrepresents the book.
- Any claim that one credit band is over-represented in the severe-shock band
  must be stated as **lift against the base composition of the renewing book**,
  never as a bare percentage. A band being 73% of the severe cohort means
  nothing until you know it's 53% of the book it came from.

---

# PART 8 — Verification

After any change:

```
python -m <pkg>.pipeline all                            # quality gate must pass
cd dbt/<project> && dbt build --profiles-dir .          # all tests must pass
cd dbt/<project> && dbt build --profiles-dir . --target postgres
```

Reproducibility check — identical checksums prove the seed works:
```
md5sum data/staged/*.parquet > run1
python -m <pkg>.pipeline simulate
md5sum data/staged/*.parquet > run2
diff run1 run2
```

If a change alters a published figure, update the README findings, the KPI
baselines, and regenerate the data dictionary.

---

# PART 9 — Portfolio context beyond this project

Two older SQL repos need fixing, and one is urgent:
**`Operations-Metric-Analytics`** has a README claiming findings the queries
don't produce — a "15% engagement lift from personalized subject lines" when
there is no subject-line data in the schema and no query computes it. **That is
the highest credibility risk in the whole portfolio.** Fix: run the queries,
commit the real outputs as CSVs, and quote only numbers that appear in them.

Job search strategy from Part 1: search on the work not the title; target
mid-market before big banks (they mostly convert co-ops); apply to the 3-year
postings whose wording accepts academic projects; and in a cover letter map
their posting's bullets to this project's components — almost nobody does that.
