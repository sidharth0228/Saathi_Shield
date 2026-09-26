"""
Tests for the Trip Guardian feature schema.

Validates structural integrity of the schema registry: no duplicate
column names, every entry carries all required metadata fields, and
meta-columns are correctly flagged as excluded from model input.
"""

from __future__ import annotations

import pytest

from ml.features.schema import (
    SCHEMA,
    REQUIRED_FIELD_NAMES,
    FeatureSpec,
    excluded_columns,
    feature_names,
    model_input_features,
)


# ────────────────────────────────────────────────────────────────────
# Structural integrity
# ────────────────────────────────────────────────────────────────────


class TestSchemaStructure:
    """Guard-rails on the shape of the schema list itself."""

    def test_schema_is_non_empty(self) -> None:
        assert len(SCHEMA) > 0, "SCHEMA must contain at least one entry."

    def test_all_entries_are_feature_specs(self) -> None:
        for entry in SCHEMA:
            assert isinstance(entry, FeatureSpec), (
                f"Expected FeatureSpec, got {type(entry).__name__}"
            )

    def test_no_duplicate_names(self) -> None:
        names = [f.name for f in SCHEMA]
        duplicates = [n for n in names if names.count(n) > 1]
        assert len(names) == len(set(names)), (
            f"Duplicate feature names found: {sorted(set(duplicates))}"
        )

    def test_every_entry_has_all_required_keys(self) -> None:
        for spec in SCHEMA:
            for key in REQUIRED_FIELD_NAMES:
                assert hasattr(spec, key), (
                    f"Feature '{spec.name}' is missing required key '{key}'"
                )
                # Also verify the value is not None (dataclass fields with
                # no default would fail at construction, but belt-and-braces).
                assert getattr(spec, key) is not None, (
                    f"Feature '{spec.name}' has None for required key '{key}'"
                )


# ────────────────────────────────────────────────────────────────────
# Excluded meta-columns
# ────────────────────────────────────────────────────────────────────


class TestExcludedColumns:
    """Ensure bookkeeping / ground-truth columns cannot leak into features."""

    def test_trip_id_is_excluded(self) -> None:
        excluded_names = {f.name for f in excluded_columns()}
        assert "trip_id" in excluded_names

    def test_true_scenario_type_is_excluded(self) -> None:
        excluded_names = {f.name for f in excluded_columns()}
        assert "true_scenario_type" in excluded_names

    def test_exactly_two_columns_are_excluded(self) -> None:
        assert len(excluded_columns()) == 2, (
            f"Expected exactly 2 excluded columns, found {len(excluded_columns())}: "
            f"{[f.name for f in excluded_columns()]}"
        )

    def test_excluded_columns_not_in_model_input_names(self) -> None:
        input_names = set(feature_names(include_excluded=False))
        for col in excluded_columns():
            assert col.name not in input_names, (
                f"Excluded column '{col.name}' leaked into model input feature names"
            )


# ────────────────────────────────────────────────────────────────────
# Model-input features
# ────────────────────────────────────────────────────────────────────


class TestModelInputFeatures:
    """Sanity checks on the features the model actually consumes."""

    def test_model_input_count_is_positive(self) -> None:
        inputs = model_input_features()
        assert len(inputs) > 0, "Must have at least one model-input feature."

    def test_model_inputs_have_excluded_false(self) -> None:
        for f in model_input_features():
            assert f.excluded_from_model_input is False, (
                f"Feature '{f.name}' is in model_input_features() but "
                f"has excluded_from_model_input=True"
            )

    def test_model_inputs_plus_excluded_equals_full_schema(self) -> None:
        assert len(model_input_features()) + len(excluded_columns()) == len(SCHEMA)


# ────────────────────────────────────────────────────────────────────
# dtype / source value validation
# ────────────────────────────────────────────────────────────────────

VALID_DTYPES = {"float", "int", "bool", "datetime", "categorical"}
VALID_SOURCES = {"GPS", "ENG"}


class TestFieldValues:
    """Ensure every entry uses the agreed-upon vocabulary."""

    @pytest.mark.parametrize("spec", SCHEMA, ids=lambda s: s.name)
    def test_dtype_is_valid(self, spec: FeatureSpec) -> None:
        assert spec.dtype in VALID_DTYPES, (
            f"Feature '{spec.name}' has invalid dtype '{spec.dtype}'; "
            f"allowed: {VALID_DTYPES}"
        )

    @pytest.mark.parametrize("spec", SCHEMA, ids=lambda s: s.name)
    def test_source_is_valid(self, spec: FeatureSpec) -> None:
        assert spec.source in VALID_SOURCES, (
            f"Feature '{spec.name}' has invalid source '{spec.source}'; "
            f"allowed: {VALID_SOURCES}"
        )

    @pytest.mark.parametrize("spec", SCHEMA, ids=lambda s: s.name)
    def test_name_is_snake_case(self, spec: FeatureSpec) -> None:
        assert spec.name == spec.name.lower(), (
            f"Feature name '{spec.name}' is not snake_case"
        )
        assert " " not in spec.name, (
            f"Feature name '{spec.name}' contains spaces"
        )

    @pytest.mark.parametrize("spec", SCHEMA, ids=lambda s: s.name)
    def test_description_is_non_empty(self, spec: FeatureSpec) -> None:
        assert len(spec.description.strip()) > 0, (
            f"Feature '{spec.name}' has an empty description"
        )


# ────────────────────────────────────────────────────────────────────
# Section 4.6 exclusion guard
# ────────────────────────────────────────────────────────────────────

FORBIDDEN_CONTEXTUAL_FEATURES = {
    "area_risk_prior",
    "historical_traffic_condition",
    "road_type",
    "location_density",
    "historical_trip_anomaly_frequency",
}


class TestContextualFeaturesExcluded:
    """Section 4.6 features must NOT appear in v1."""

    def test_no_forbidden_contextual_features_present(self) -> None:
        schema_names = {f.name for f in SCHEMA}
        leaked = schema_names & FORBIDDEN_CONTEXTUAL_FEATURES
        assert len(leaked) == 0, (
            f"Section 4.6 contextual features must not appear in v1 schema: {leaked}"
        )
