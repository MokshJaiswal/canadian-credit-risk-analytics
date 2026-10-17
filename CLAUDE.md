# Canadian Credit Risk Analytics

Flagship data-analyst portfolio project. **Simple but impactful**: a clear
business question, good SQL, a Power BI dashboard, and honest findings.

Background (market research, domain explainer, KPI definitions, traps) is in
[docs/PROJECT-BRIEF.md](docs/PROJECT-BRIEF.md). **The brief's architecture
and build plan are superseded by this file** — the owner found them too
complex. Use the brief for domain knowledge, not for scope.

**Business question:** Canadian mortgages written in the 2020–22 low-rate era
renew 2025–27 at higher rates. Which segments, products and regions carry the
most payment-shock and default risk, how much provision does that imply, and
who should retention outreach call first?

## The owner

Recent graduate job-hunting as a **data analyst** in Toronto. Not a software
engineer. On Windows. Must be able to explain every line in an interview.
Has twice said the code felt "like a senior programmer" — take that seriously.

## Rules

1. **Keep it simple.** Write Python the way a data analyst or data engineer
   writes it, not a software developer: scripts that read top to bottom,
   pandas, few functions, and SQL for anything set-based. No classes,
   decorators, mocking, retry taxonomies, frameworks or "for later" plumbing.
   If explaining something takes more than a sentence, simplify it.
2. **Never state a figure the code didn't produce.** Every number in the README
   or dashboard must come from a query.
3. **Never present simulated data as real.** The loan book is generated; interest
   rates (Bank of Canada), unemployment (StatCan) and mortgage arrears (CBA) are
   real. Every table carries a `source` column, and the dashboard says which is which.
4. Simple doesn't excuse wrong. Data is checked with SQL queries in
   `sql/03_quality_checks.sql` (duplicates, nulls, totals reconcile) — that replaces unit
   tests. Tunable numbers live in `config/pipeline.yml` with a comment saying
   where each came from.

## What exists (built and verified 2026-10-17)

| File | Does |
| --- | --- |
| `src/fetch_rates.py` | Real Bank of Canada rates → `data/rates.csv` (monthly averages) |
| `src/fetch_provincial_data.py` | Real StatCan unemployment/population by province + CBA mortgage arrears by region → `data/unemployment.csv`, `data/mortgage_arrears.csv` |
| `src/logger.py` | Logging to screen + `logs/pipeline.log` |
| `notebooks/01_simulate_loans.ipynb` | 50k seeded loans priced off real rates; province mix from real CBA mortgage counts → `data/loans.csv` |
| `notebooks/02_simulate_performance.ipynb` | Monthly roll-rate simulation; hazard × real regional arrears factor (WHERE) × real unemployment over time (WHEN) → `data/loan_months.parquet` |
| `notebooks/03_build_warehouse.ipynb` | Runs `sql/01-05` in DuckDB (`data/warehouse.duckdb`), quality gate (23 checks), Q1–Q12, validation Q13–Q15, exports |
| `notebooks/04_analysis_and_charts.ipynb` | pandas + seaborn charts → `images/` |
| `notebooks/05_default_risk_model.ipynb` | Logistic regression (scikit-learn) |
| `sql/01..05` | load raw → star schema + analysis + `arrears_validation` → 23 quality checks → Q1–Q15 → Power BI CSVs |
| `powerbi/data/*.csv` | Committed exports for the dashboard |
| `docs/POWERBI_GUIDE.md` | Dashboard model, DAX, pages, expected values (from Q12) |
| `README.md` | Findings — every number cites a query (Q1–Q12) |

The owner builds the Power BI report themselves from the guide. Later: dbt port of `sql/`.

Out of scope: Postgres, Streamlit, GitHub Actions, the lender-rate scraper,
pytest, bootstrap scripts, foreclosure-timeline modelling.

**Real-data design (2026-10-17):** real arrears and real unemployment correlate
over TIME (0.69) but not across REGIONS (−0.29), so regional risk comes from the
CBA arrears level (calibrated: the regional match is NOT a validation) and timing
from national unemployment (the trend vs real arrears IS the validation: quarterly
corr 0.41, level 0.41× real). Report these gaps; don't tune them away.

**If any number changes** (config, simulation, SQL): run both fetch scripts, re-run
notebooks 01→05, then update README findings, `docs/PROJECT_EXPLAINED.md`, the
narrated presentation (claude.ai artifact), and the expected values in
`docs/POWERBI_GUIDE.md` from Q1–Q15. Notebook sources are edited as notebooks
(cells), not `.py`.

## Lessons from the build (don't repeat)

- Each simulation notebook needs its **own seed** (01 uses `seed`, 02 uses `seed + 1`):
  sharing one made month-1 draws reuse the product-choice draws.
- DuckDB `GROUP BY` returns rows in no fixed order — add `ORDER BY` before any
  train/test split or anything that must be reproducible.
- Model features must not be shaped by the outcome (rows stop after default, so
  "rows per loan" leaks the target).
- VS Code's SQL Server extension flags valid DuckDB syntax; its error checking is
  off in `.vscode/settings.json`.
- The CBA arrears file lags ~2 months behind the window and its URL contains the
  month (`config/pipeline.yml`). Keep what exists, never fill gaps.
- `.gitignore`: comments must be on their own line, and ignore only `/data/`
  (a bare `data/` also hid `powerbi/data/`, which IS committed).
- In PowerShell, `R` is an alias (Invoke-History) — don't name helper functions `R`.
  For long multi-line doc edits, use a small Python find/replace script.

## Working style

- The owner asked (2026-10-17) for whole steps to be built **and verified end to
  end** by Claude: run every notebook, read the outputs, look at every chart,
  check numbers against each other. Keep the code entry-level regardless.
- Analysis, wrangling and modelling go in Jupyter notebooks (`notebooks/*.ipynb`)
  with markdown explaining each step; set-based logic goes in `sql/*.sql`. Plain
  data-fetching stays a `.py` script. Only create files that are needed.
- Notebooks start with a cell that `chdir`s to the project root if run from
  `notebooks/`, so paths are always `config/...`, `data/...`.
- Branch `build/pipeline`, not `main`.

## Domain traps to remember (detail in brief Part 6)

- YAML reads bare `ON` as `true` — quote province codes.
- BoC `V80691335` is the *posted* rate. What people actually pay on a fixed
  mortgage ≈ 5-yr GoC bond yield + 1.40pp. Fixed tracks bonds; variable tracks prime.
- Delinquency: current accounts *enter* at the hazard rate; delinquent accounts
  *cure* or *roll forward* — otherwise defaults never happen.
- Credit-score pricing differs by product (~0.15pp/100pts mortgage, ~5.5 card),
  with rate floors (fixed ≥ 1.35%, variable ≥ 0.95%).
- Only SUM a column at the grain it was measured at (a join once inflated the book 38×).
- Store amounts, not ratios: `delinquent_balance_cad`, with rates computed in
  Power BI as `DIVIDE(SUM(...), SUM(...))`. Weight payment shock by balance.
- Never `min()` a text column to report provenance — use `string_agg(distinct ...)`.

## Environment (Windows)

- Python **3.12** in `.venv` (default `python` outside it is 3.14, which also
  has pandas, so it can look like it works). Use `.venv\Scripts\python`.
- `OPENBLAS_NUM_THREADS=4` is set in `.vscode/settings.json` — numpy crashed
  at import when memory was tight.
- Memory is tight: the Claude desktop app's `CoworkVMService` holds ~4 GB and
  restarts at boot (`Stop-Service CoworkVMService` as admin to free it).
- Project lives at `C:\dev\` — never OneDrive (file locks corrupt DuckDB).
- GitHub account is **MokshJaiswal**. If `gh` isn't on PATH:
  `& "C:\Program Files\GitHub CLI\gh.exe"`.
- pandas 3.x: use `df.loc[mask, "col"] = value`; chained assignment silently does nothing.
