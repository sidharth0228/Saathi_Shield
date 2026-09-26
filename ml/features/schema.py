"""
Trip Guardian ML — Machine-readable feature schema.

This module is the single authoritative registry of every column that
appears in a Trip Guardian dataset row (one row = one 60-second trip
window).  All generators, feature-engineering steps, and model training
scripts import from here rather than hard-coding column names.

Design decisions
----------------
* Dataclass-based: each column is a frozen ``FeatureSpec`` instance so
  the schema is introspectable at runtime and IDE-friendly.
* Two meta-columns (``trip_id``, ``true_scenario_type``) are flagged
  ``excluded_from_model_input=True``; they travel with the data for
  bookkeeping but must never enter a feature matrix.
* Section 4.6 "optional contextual" features (area_risk_prior,
  historical_traffic_condition, road_type, location_density,
  historical_trip_anomaly_frequency) are deliberately **omitted** from
  v1 because the external datasets they require are unavailable.
  Placeholder columns for them are explicitly forbidden by the Phase 1
  README.

Source conventions
------------------
* ``"GPS"`` — value derived directly from raw GPS fixes (lat, lng,
  speed, bearing) within the 60-second window.
* ``"ENG"`` — value engineered / computed from GPS-derived quantities,
  session metadata, or calendar lookups.  Not a raw sensor reading.
"""

from __future__ import annotations

from dataclasses import dataclass, fields
from typing import List


@dataclass(frozen=True)
class FeatureSpec:
    """Specification for a single column in a trip-window dataset row."""

    name: str
    """Snake_case column name used in DataFrames and feature vectors."""

    dtype: str
    """Logical data type: ``'float'``, ``'int'``, ``'bool'``, ``'datetime'``, or ``'categorical'``."""

    unit: str
    """Physical or logical unit (e.g. ``'m'``, ``'m/s'``, ``'unitless'``, ``'identifier'``)."""

    required: bool
    """If ``True`` the column must be present and non-null in every row."""

    source: str
    """Data origin — ``'GPS'`` (raw sensor) or ``'ENG'`` (engineered)."""

    description: str
    """One-line human-readable explanation of what the column represents."""

    excluded_from_model_input: bool = False
    """If ``True`` this column must never be used as a model input feature.
    It exists for bookkeeping / ground-truth labelling only."""


# ────────────────────────────────────────────────────────────────────
# Required keys that every FeatureSpec must carry.  Used by tests and
# validation helpers.
# ────────────────────────────────────────────────────────────────────
REQUIRED_FIELD_NAMES: frozenset[str] = frozenset(
    f.name for f in fields(FeatureSpec) if f.name != "excluded_from_model_input"
)


# ====================================================================
#  SCHEMA — the authoritative list of columns
# ====================================================================

SCHEMA: List[FeatureSpec] = [

    # ── Meta-columns (excluded from model input) ────────────────────

    FeatureSpec(
        name="trip_id",
        dtype="categorical",
        unit="identifier",
        required=True,
        source="ENG",
        description="Unique identifier for the travel session this window belongs to.",
        excluded_from_model_input=True,
    ),
    FeatureSpec(
        name="true_scenario_type",
        dtype="categorical",
        unit="label",
        required=True,
        source="ENG",
        description="Generator ground-truth scenario label (e.g. NORMAL, SUSPICIOUS, HIGH_RISK); never used as model input.",
        excluded_from_model_input=True,
    ),

    # ── 4.1  Route-related features ─────────────────────────────────

    FeatureSpec(
        name="cross_track_error_m",
        dtype="float",
        unit="m",
        required=True,
        source="GPS",
        description="Perpendicular distance from the current position to the nearest planned-route segment.",
    ),
    FeatureSpec(
        name="cumulative_off_route_m",
        dtype="float",
        unit="m",
        required=True,
        source="GPS",
        description="Total distance traveled outside the route corridor during this window.",
    ),
    FeatureSpec(
        name="route_progress_fraction",
        dtype="float",
        unit="unitless",
        required=True,
        source="GPS",
        description="Fraction of the planned route completed so far (0.0 at origin, 1.0 at destination).",
    ),
    FeatureSpec(
        name="distance_to_destination_m",
        dtype="float",
        unit="m",
        required=True,
        source="GPS",
        description="Great-circle distance from the current position to the trip destination.",
    ),

    # ── 4.2  Movement features ──────────────────────────────────────

    FeatureSpec(
        name="mean_speed_mps",
        dtype="float",
        unit="m/s",
        required=True,
        source="GPS",
        description="Mean GPS-derived speed over the 60-second window.",
    ),
    FeatureSpec(
        name="max_speed_mps",
        dtype="float",
        unit="m/s",
        required=True,
        source="GPS",
        description="Peak instantaneous speed recorded in the window.",
    ),
    FeatureSpec(
        name="speed_std_mps",
        dtype="float",
        unit="m/s",
        required=True,
        source="GPS",
        description="Standard deviation of speed samples within the window.",
    ),
    FeatureSpec(
        name="mean_acceleration_mps2",
        dtype="float",
        unit="m/s²",
        required=True,
        source="ENG",
        description="Mean absolute acceleration derived from consecutive speed deltas.",
    ),
    FeatureSpec(
        name="heading_change_rate_dps",
        dtype="float",
        unit="deg/s",
        required=True,
        source="GPS",
        description="Mean rate of GPS-bearing change across fixes in the window.",
    ),

    # ── 4.3  Stop features ──────────────────────────────────────────

    FeatureSpec(
        name="stop_duration_s",
        dtype="float",
        unit="s",
        required=True,
        source="GPS",
        description="Total seconds spent below the stop-speed threshold (< 0.5 m/s) in this window.",
    ),
    FeatureSpec(
        name="is_stopped",
        dtype="bool",
        unit="unitless",
        required=True,
        source="GPS",
        description="Whether the traveler is stationary at the end of the window.",
    ),
    FeatureSpec(
        name="stop_count",
        dtype="int",
        unit="count",
        required=True,
        source="GPS",
        description="Number of distinct stop-start transitions during the window.",
    ),

    # ── 4.4  Trip-timing features ───────────────────────────────────

    FeatureSpec(
        name="hour_sin",
        dtype="float",
        unit="unitless",
        required=True,
        source="ENG",
        description="Sine component of cyclical hour-of-day encoding: sin(2π × hour / 24).",
    ),
    FeatureSpec(
        name="hour_cos",
        dtype="float",
        unit="unitless",
        required=True,
        source="ENG",
        description="Cosine component of cyclical hour-of-day encoding: cos(2π × hour / 24).",
    ),
    FeatureSpec(
        name="day_of_week",
        dtype="int",
        unit="[0-6]",
        required=True,
        source="ENG",
        description="ISO day of week (0 = Monday, 6 = Sunday).",
    ),
    FeatureSpec(
        name="is_weekend",
        dtype="bool",
        unit="unitless",
        required=True,
        source="ENG",
        description="True if the window falls on a Saturday or Sunday.",
    ),
    FeatureSpec(
        name="is_night",
        dtype="bool",
        unit="unitless",
        required=True,
        source="ENG",
        description="True if the local hour is between 20:00 and 06:00.",
    ),
    FeatureSpec(
        name="trip_elapsed_s",
        dtype="float",
        unit="s",
        required=True,
        source="ENG",
        description="Wall-clock seconds elapsed since the travel session started.",
    ),

    # ── 4.5  Route-behaviour features ───────────────────────────────

    FeatureSpec(
        name="deviation_count",
        dtype="int",
        unit="count",
        required=True,
        source="ENG",
        description="Cumulative number of route-corridor exits observed since trip start.",
    ),
    FeatureSpec(
        name="consecutive_deviation_windows",
        dtype="int",
        unit="count",
        required=True,
        source="ENG",
        description="Number of consecutive preceding windows with cross-track error above the corridor threshold.",
    ),
    FeatureSpec(
        name="speed_vs_expected_ratio",
        dtype="float",
        unit="unitless",
        required=True,
        source="ENG",
        description="Ratio of observed mean speed to the expected speed for the matched route segment.",
    ),
    FeatureSpec(
        name="bearing_alignment_deg",
        dtype="float",
        unit="deg",
        required=True,
        source="GPS",
        description="Absolute angular difference between the current heading and the planned route direction.",
    ),
]


# ====================================================================
#  Convenience accessors
# ====================================================================

def model_input_features() -> List[FeatureSpec]:
    """Return only the features that should enter the model's input matrix."""
    return [f for f in SCHEMA if not f.excluded_from_model_input]


def excluded_columns() -> List[FeatureSpec]:
    """Return meta-columns that must be kept out of model input."""
    return [f for f in SCHEMA if f.excluded_from_model_input]


def feature_names(include_excluded: bool = False) -> List[str]:
    """Return an ordered list of column names.

    Parameters
    ----------
    include_excluded : bool
        If *False* (default) meta-columns are omitted.
    """
    return [
        f.name for f in SCHEMA
        if include_excluded or not f.excluded_from_model_input
    ]
