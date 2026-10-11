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
3. **Never present simulated data as real.** The loan book is generated; the
   interest rates are real. Every table carries a `source` column, and the
   dashboard says which is which.
4. Simple doesn't excuse wrong. Data is checked with SQL queries in
   `sql/checks.sql` (duplicates, nulls, totals reconcile) — that replaces unit
   tests. Tunable numbers live in `config/pipeline.yml` with a comment saying
   where each came from.

## The plan

| # | File | Does |
| --- | --- | --- |
| 1 | `src/fetch_rates.py` | Real Bank of Canada rates → `data/rates.csv` (monthly averages) |
| 2 | `notebooks/simulate_loans.ipynb` | Seeded loan book priced off those rates → `data/loans.csv` |
| 2b | `notebooks/simulate_performance.ipynb` | Monthly delinquency → default, per loan |
| 3 | `sql/*.sql` + `src/build_warehouse.py` | Load into DuckDB, build analysis tables, run checks |
| 4 | Power BI report | Reads exported CSVs; includes a data-quality page |
| 5 | `README.md` | Business question, findings (query-backed), how to run |
| later | dbt | Port the `sql/` models to dbt once everything works |

Out of scope: Postgres, StatCan, Streamlit, GitHub Actions, the lender-rate
scraper, pytest, bootstrap scripts.

## Working style

- **One file at a time.** Stop after each so the owner can run it.
- **The owner runs the analysis themselves.** Analysis, wrangling and
  modelling code goes in Jupyter notebooks (`notebooks/*.ipynb`); SQL goes in
  `.sql` files. Plain data-fetching stays a `.py` script. Say what each cell
  should show; they verify by running it. VS Code runs notebooks from the
  project folder (`jupyter.notebookFileRoot`), so paths are `config/...`, `data/...`.
- Before each change: 2–3 lines on what and why.
- After each change: the exact command and what they should see.
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
