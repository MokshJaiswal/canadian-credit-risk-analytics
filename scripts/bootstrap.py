"""Verify the environment actually works, not just that pip exited 0.

Run: .venv\\Scripts\\python scripts\\bootstrap.py
Exits 1 if anything fails, so it can gate automation later.
"""
import importlib
import sys
from pathlib import Path

# Let this script find the ccra package even when PYTHONPATH isn't set.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

# Import name -> what it's for. Import names differ from pip names
# (PyYAML imports as yaml, psycopg2-binary as psycopg2).
PACKAGES = {
    "pandas": "analysis",
    "numpy": "analysis",
    "pyarrow": "Parquet files",
    "requests": "API clients",
    "yaml": "config file",
    "duckdb": "local warehouse",
    "dbt.adapters.duckdb": "dbt on DuckDB",
    "streamlit": "dashboard",
    "plotly": "dashboard charts",
    "black": "formatting",
    "pytest": "tests",
}


def check_python() -> bool:
    """dbt can't resolve dependencies on 3.13+, so only 3.11 and 3.12 pass."""
    ok = sys.version_info[:2] in [(3, 11), (3, 12)]
    print(f"{'OK  ' if ok else 'FAIL'} python {sys.version.split()[0]} (need 3.11 or 3.12)")
    return ok


def check_imports() -> bool:
    all_ok = True
    for name, purpose in PACKAGES.items():
        try:
            module = importlib.import_module(name)
            version = getattr(module, "__version__", "")
            print(f"OK   {name} {version}  ({purpose})")
        except ImportError as error:
            print(f"FAIL {name}  ({purpose}): {error}")
            all_ok = False
    return all_ok


def check_duckdb_query() -> bool:
    """An import can succeed while the engine is broken; run a real query."""
    try:
        import duckdb

        result = duckdb.sql("select 1 + 1").fetchone()[0]
        ok = result == 2
    except Exception as error:
        print(f"FAIL duckdb query: {error}")
        return False
    print(f"{'OK  ' if ok else 'FAIL'} duckdb query returned {result}")
    return ok


def check_config() -> bool:
    """A green bootstrap should mean the pipeline can start, so load the real config."""
    try:
        from ccra.config import CONFIG_PATH, load_config

        load_config()
    except Exception as error:
        print(f"FAIL config: {error}")
        return False
    print(f"OK   config loads and validates ({CONFIG_PATH.name})")
    return True


if __name__ == "__main__":
    # Run every check (no short-circuit) so one run shows all problems.
    results = [check_python(), check_imports(), check_duckdb_query(), check_config()]
    if all(results):
        print("\nEnvironment OK")
    else:
        print("\nEnvironment has problems - see FAIL lines above")
        sys.exit(1)
