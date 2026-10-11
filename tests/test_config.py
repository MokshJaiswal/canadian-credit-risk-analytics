"""Each test breaks one thing in a copy of the real config and checks the
validator catches it. Run: python -m pytest tests -v
"""
import pytest
import yaml

from ccra.config import CONFIG_PATH, load_config, validate_config


def raw_config() -> dict:
    """A fresh read of the real YAML, unvalidated, so each test can break its own copy."""
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return yaml.safe_load(f)


def test_real_config_is_valid():
    load_config()  # raises if invalid


def test_product_mix_must_sum_to_one():
    config = raw_config()
    config["portfolio"]["product_mix"]["mortgage"] = 0.40
    with pytest.raises(ValueError, match="product_mix sums to 1.050000"):
        validate_config(config)


def test_regional_shares_must_sum_to_one():
    config = raw_config()
    config["portfolio"]["regional_shares"]["ON"] = 0.5
    with pytest.raises(ValueError, match="regional_shares sums to"):
        validate_config(config)


def test_negative_share_rejected():
    config = raw_config()
    config["portfolio"]["mortgage_rate_type_mix"] = {"fixed": 1.25, "variable": -0.25}
    with pytest.raises(ValueError, match="is negative"):
        validate_config(config)


def test_unquoted_on_becomes_true_and_is_caught():
    """Trap #1: YAML reads a bare ON as boolean True."""
    text = CONFIG_PATH.read_text(encoding="utf-8").replace('"ON":', "ON:")
    config = yaml.safe_load(text)
    assert True in config["portfolio"]["regional_shares"]  # proves the trap is real
    with pytest.raises(ValueError, match="key True is not a string"):
        validate_config(config)


def test_dates_must_be_in_order():
    config = raw_config()
    config["window"]["performance_start"] = "2027-01-01"
    with pytest.raises(ValueError, match="performance_start .* must be before performance_end"):
        validate_config(config)


def test_every_product_needs_a_risk_section():
    config = raw_config()
    del config["risk"]["card"]
    with pytest.raises(ValueError, match="risk section missing for product 'card'"):
        validate_config(config)


def test_probabilities_must_be_between_zero_and_one():
    config = raw_config()
    config["risk"]["mortgage"]["lgd"] = 1.5
    with pytest.raises(ValueError, match="risk.mortgage.lgd must be between 0 and 1"):
        validate_config(config)


def test_all_errors_reported_at_once():
    config = raw_config()
    config["portfolio"]["product_mix"]["mortgage"] = 0.40
    del config["risk"]["card"]
    with pytest.raises(ValueError) as error:
        validate_config(config)
    assert "product_mix" in str(error.value)
    assert "risk section missing" in str(error.value)
