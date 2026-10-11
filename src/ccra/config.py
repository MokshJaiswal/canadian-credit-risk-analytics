"""Load and validate config/pipeline.yml.

Every stage calls load_config() first, so a bad setting stops the pipeline
before it fetches data or writes files - not halfway through.

Run: python -m ccra.config
"""
import math
from datetime import date
from pathlib import Path

import yaml

# src/ccra/config.py -> repo root is two folders up from src/ccra
REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = REPO_ROOT / "config" / "pipeline.yml"


def load_config(path: Path = CONFIG_PATH) -> dict:
    """Read the YAML and validate it, so callers never see a bad config."""
    if not path.exists():
        raise FileNotFoundError(f"Config not found: {path}")
    with open(path, encoding="utf-8") as f:
        config = yaml.safe_load(f)
    validate_config(config)
    return config


def check_mix(name: str, mix: dict) -> list[str]:
    """A mix of shares must be non-negative and sum to 1.0."""
    errors = []
    total = sum(mix.values())
    # isclose, not ==, because 0.1 + 0.2 != 0.3 in floating point
    if not math.isclose(total, 1.0, abs_tol=1e-6):
        errors.append(f"{name} sums to {total:.6f}, expected 1.0")
    for key, share in mix.items():
        if share < 0:
            errors.append(f"{name}[{key}] is negative: {share}")
    return errors


def validate_config(config: dict) -> None:
    """Collect every problem, then raise once, so one run shows them all."""
    errors = []
    portfolio = config["portfolio"]

    # 1. Mixes sum to 1.0
    errors += check_mix("product_mix", portfolio["product_mix"])
    errors += check_mix("mortgage_rate_type_mix", portfolio["mortgage_rate_type_mix"])
    errors += check_mix("regional_shares", portfolio["regional_shares"])

    # 2. Province keys are strings (YAML turns a bare ON into True - trap #1)
    for key in portfolio["regional_shares"]:
        if not isinstance(key, str):
            errors.append(f"regional_shares key {key!r} is not a string - quote it in the YAML")

    # 3. Dates are in order
    window = config["window"]
    order = ["macro_start", "origination_start", "performance_start", "performance_end"]
    for i in range(len(order) - 1):
        earlier, later = order[i], order[i + 1]
        if date.fromisoformat(window[earlier]) >= date.fromisoformat(window[later]):
            errors.append(f"window.{earlier} ({window[earlier]}) must be before {later} ({window[later]})")

    # 4. Every product has a risk section, with probabilities in [0, 1]
    for product in portfolio["product_mix"]:
        if product not in config["risk"]:
            errors.append(f"risk section missing for product '{product}'")
            continue
        for field in ["target_cum_default_42m", "cure_rate", "lgd"]:
            value = config["risk"][product].get(field)
            if value is None or not 0 <= value <= 1:
                errors.append(f"risk.{product}.{field} must be between 0 and 1, got {value}")

    if errors:
        raise ValueError("Invalid config:\n  - " + "\n  - ".join(errors))


if __name__ == "__main__":
    config = load_config()
    print(f"Config OK: {CONFIG_PATH}")
    print(f"  products: {list(config['portfolio']['product_mix'])}")
    print(f"  regions:  {list(config['portfolio']['regional_shares'])}")
    print(f"  window:   {config['window']['performance_start']} to {config['window']['performance_end']}")
