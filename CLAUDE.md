# Canadian Credit Risk Analytics

Flagship data-analyst portfolio project. The full spec is
[docs/PROJECT-BRIEF.md](docs/PROJECT-BRIEF.md) — read it before building
anything. This file is the short version that must never be skipped.

**Business question:** Canadian mortgages written in the 2020–22 low-rate era
renew 2025–27 at higher rates. Which segments, products and regions carry the
most payment-shock and default risk, how much provision does that imply, and
who should retention outreach call first?

## The owner

Recent graduate job-hunting as a **data analyst** in Toronto. Not a software
engineer. On Windows. Must be able to explain every line in an interview.

## Non-negotiable rules

1. **Analyst-level code.** Plain functions over DataFrames, pandas/numpy
   idioms, dicts for data, type hints on signatures, short docstrings saying
   *why*, SQL for anything set-based. **Do not write:** `@dataclass`,
   `@property` over dict lookups, `@contextmanager`, custom exception
   hierarchies (use `ValueError` / `FileNotFoundError`), abstract base classes,
   factories, dependency injection, `from __future__ import annotations`.
   If explaining a construct takes more than a sentence, simplify it. Heavy
   pandas/numpy is fine — the over-engineering risk is in the plumbing.
2. **Never state a figure the code didn't produce.** Every number in a README
   or doc must be backed by a query. An unverifiable number is worse than none.
3. **Never present simulated data as real.** The loan book is generated; macro
   data is real. Stamp a `source` column on every row and surface provenance on
   the dashboard.
4. These rules **do not** excuse correctness bugs, missing tests, or
   undocumented magic numbers. Every tunable lives in `config/pipeline.yml`.

## Working style

- **One file at a time.** Stop after each so the owner can run it. Never land a
  multi-file diff they can't review.
- Before each change: 2–3 lines on what and why.
- After each change: the exact command and what they should expect to see.
- Follow the build plan in order (brief Part 4). Don't build ahead.
- Work on branch `build/pipeline`, not `main`.

## Architecture (brief Part 3)

```text
Bank of Canada Valet + StatCan WDS → ingest → macro.parquet (source-stamped)
      → seeded simulator (macro-driven hazard, roll-rate state machine)
      → borrowers / accounts / account_month
      → landing schema in DuckDB, verbatim
      → data quality gate (error severity exits non-zero)
      → dbt: staging views → marts star schema + tests
      → Parquet/CSV extracts → Power BI (import mode) + Streamlit
```

Build steps: 0 env → 1 config → 2 ingest → 3 simulate → 4 warehouse →
5 quality gate → 6 dbt star schema → 7 export + Power BI → 8 automation + docs
→ 9 lender-rate scraper.

## Decisions that override the brief

- **DuckDB only, no Postgres** (2026-10-11). Supporting both meant two SQL
  dialects and a database server to run, for no interview value. Write
  standard SQL; the README can say dbt ports it to Postgres/Snowflake by
  changing the connection. Ignore brief references to the Postgres target,
  `dbt-postgres`, and trap #6's dual-dialect macro file.
- **Entry-level code, even below the brief's bar.** The owner flagged early
  code as reading "like a senior programmer". Take the version a junior
  analyst would write: separate pure logic (data in → DataFrame out) from
  network/file I/O, test the logic with plain inputs, no mocking.
- **Valet series are averaged to monthly** (not month-end): the rates price
  originations during the month.

## Traps a previous attempt hit (detail in brief Part 6)

1. YAML reads bare `ON` as `true` — quote province codes; validate keys are strings.
2. BoC `V80691335` is the *posted* rate. Transacted fixed = 5-yr GoC yield +
   ~1.40pp (spread in config). Fixed tracks bonds; variable tracks prime.
3. Roll-rate: current accounts *enter* delinquency at the hazard rate;
   delinquent accounts *cure* or *roll forward* — no fresh hazard draw.
4. Credit-score pricing sensitivity is product-specific (~0.15/100pts
   mortgage, ~5.5 card) with product-specific rate floors.
5. `dbt.type_float()` is 4-byte in DuckDB — cast money/rates to `double precision`.
6. DuckDB ≠ Postgres SQL — moot while we're DuckDB-only (see Decisions).
7. Never `min()` a string to report provenance — use `string_agg(distinct ...)`.
8. Only SUM a column at the grain it was measured at (dim join fanned out 38×).
9. Trace one value end to end, source API → dashboard KPI.

Also: store additive numerators (`delinquent_balance_cad`), never ratios —
ratios are DAX `DIVIDE(SUM, SUM)`. Exposure-weight payment shock.

## Environment (Windows, learned in Step 0)

- **Python 3.12 via `py -3.12`.** Default `py`/`python` outside the venv is
  3.14, which dbt can't use and which also has pandas installed — so it can
  look like it works. Always use `.venv\Scripts\python`.
- Verify the environment: `.venv\Scripts\python scripts\bootstrap.py`
  (also F5 / Ctrl+Shift+B in VS Code). Exits 1 on any failure.
- `OPENBLAS_NUM_THREADS=4` is set in `.vscode/` configs: numpy's OpenBLAS
  reserved a buffer per thread (16) at import and crashed under memory
  pressure. Set it anywhere else Python runs (CI, scheduled tasks).
- **Memory is tight on this machine.** Check free commit memory before
  Steps 3–4. The Claude desktop app's `CoworkVMService` restarts at every boot
  and holds ~4 GB; stop it as admin with `Stop-Service CoworkVMService`.
  Docker Desktop autostart brings back the WSL VM (~4 GB).
- Project lives at `C:\dev\` — never OneDrive/Documents/Desktop (file locks
  corrupt DuckDB mid-write).
- GitHub account is **MokshJaiswal** (not `mokshjaiswal0046-rgb`), pinned via
  `credential.https://github.com.username`. If `gh` isn't on PATH, use
  `& "C:\Program Files\GitHub CLI\gh.exe"`.
- `data/` is gitignored, so Step 2's committed real-data snapshot lives
  outside it (e.g. `snapshots/`).
- pandas is 3.x: string dtype by default, and chained assignment silently does
  nothing — always `df.loc[mask, "col"] = value`.
