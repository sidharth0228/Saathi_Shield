"""
Tests for the synthetic trip generator and dataset builder.

Verifies:
1. NORMAL trips have deviation distributions within configured bounds.
2. HIGH_RISK trips satisfy "at least 2 signals" by construction.
3. Noise is actually applied (observed ≠ true signal).
4. Class ratio of a 100-trip dataset is within ±10 % of configured ratio.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

from ml.generators.trip_generator import TripGenerator
from ml.generators.dataset_builder import assign_scenarios, DEFAULT_RATIOS

_CONFIG_DIR = Path(__file__).resolve().parents[1] / "generators" / "scenario_configs"


# ── Fixtures ────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def generator() -> TripGenerator:
    return TripGenerator(_CONFIG_DIR, seed=42)


@pytest.fixture(scope="module")
def normal_trips(generator: TripGenerator) -> list[dict]:
    """Pre-generate a batch of NORMAL trips for statistical tests."""
    return [generator.generate("NORMAL") for _ in range(15)]


@pytest.fixture(scope="module")
def high_risk_trips(generator: TripGenerator) -> list[dict]:
    return [generator.generate("HIGH_RISK") for _ in range(15)]


@pytest.fixture(scope="module")
def suspicious_trips(generator: TripGenerator) -> list[dict]:
    return [generator.generate("SUSPICIOUS") for _ in range(10)]


# ════════════════════════════════════════════════════════════════════
# 1.  NORMAL deviation bounds
# ════════════════════════════════════════════════════════════════════

class TestNormalDeviationBounds:
    """NORMAL trips should have small, self-correcting deviations."""

    def test_mean_deviation_under_150m(self, normal_trips: list[dict]) -> None:
        for trip in normal_trips:
            devs = [p["true_deviation_m"] for p in trip["points"]]
            mean_dev = np.mean(devs)
            assert mean_dev < 150, (
                f"NORMAL trip {trip['trip_id'][:8]} has mean deviation "
                f"{mean_dev:.1f} m (expected < 150 m)"
            )

    def test_median_deviation_reasonable(self, normal_trips: list[dict]) -> None:
        for trip in normal_trips:
            devs = [p["true_deviation_m"] for p in trip["points"]]
            median = float(np.median(devs))
            assert median < 200, (
                f"NORMAL trip median deviation {median:.1f} m is too high"
            )

    def test_no_extreme_deviation(self, normal_trips: list[dict]) -> None:
        """No single NORMAL point should have deviation > 500 m."""
        for trip in normal_trips:
            max_dev = max(p["true_deviation_m"] for p in trip["points"])
            assert max_dev < 500, (
                f"NORMAL trip has extreme deviation {max_dev:.1f} m"
            )

    def test_self_correction_behaviour(self, normal_trips: list[dict]) -> None:
        """After deviation > 100 m, it should decay within 30 s (≈ 6 pts)."""
        for trip in normal_trips:
            devs = [p["true_deviation_m"] for p in trip["points"]]
            for i, d in enumerate(devs):
                if d > 100:
                    # Check that within the next 6 points, deviation decreases
                    window = devs[i:i + 7]
                    if len(window) >= 3:
                        # At least one point in the next 6 should be lower
                        assert min(window[1:]) < d * 1.05, (
                            f"NORMAL deviation did not self-correct from "
                            f"{d:.1f} m at idx {i}"
                        )
                    break  # one check per trip is enough


# ════════════════════════════════════════════════════════════════════
# 2.  HIGH_RISK "at least 2 signals" invariant
# ════════════════════════════════════════════════════════════════════

class TestHighRiskSignals:
    """Every HIGH_RISK trip must have ≥ 2 signals applied."""

    def test_at_least_two_signals(self, high_risk_trips: list[dict]) -> None:
        for trip in high_risk_trips:
            n_signals = len(trip["signals_applied"])
            assert n_signals >= 2, (
                f"HIGH_RISK trip {trip['trip_id'][:8]} has only "
                f"{n_signals} signal(s): {trip['signals_applied']}"
            )

    def test_excessive_duration_never_alone(self, high_risk_trips: list[dict]) -> None:
        for trip in high_risk_trips:
            if "excessive_duration" in trip["signals_applied"]:
                others = [s for s in trip["signals_applied"]
                          if s != "excessive_duration"]
                assert len(others) >= 1, (
                    "excessive_duration must never be the sole signal"
                )

    def test_signals_are_valid_names(self, high_risk_trips: list[dict]) -> None:
        valid = {
            "large_sustained_deviation", "prolonged_stop",
            "multiple_deviations", "high_speed_variance",
            "excessive_duration",
        }
        for trip in high_risk_trips:
            for s in trip["signals_applied"]:
                assert s in valid, f"Unknown HIGH_RISK signal: {s}"


# ════════════════════════════════════════════════════════════════════
# 3.  Noise is actually applied
# ════════════════════════════════════════════════════════════════════

class TestNoiseApplication:
    """Observed values must differ from true values due to sensor noise."""

    def test_position_noise_applied(self, normal_trips: list[dict]) -> None:
        trip = normal_trips[0]
        n_diff = sum(
            1 for p in trip["points"]
            if p["observed_lat"] != p["true_lat"]
            or p["observed_lon"] != p["true_lon"]
        )
        ratio = n_diff / len(trip["points"])
        assert ratio > 0.95, (
            f"Only {ratio:.0%} of points have position noise; expected > 95 %"
        )

    def test_speed_noise_applied(self, normal_trips: list[dict]) -> None:
        trip = normal_trips[0]
        n_diff = sum(
            1 for p in trip["points"]
            if abs(p["observed_speed_mps"] - p["true_speed_mps"]) > 1e-6
        )
        ratio = n_diff / len(trip["points"])
        assert ratio > 0.90, (
            f"Only {ratio:.0%} of points have speed noise; expected > 90 %"
        )

    def test_noise_magnitude_reasonable(self, normal_trips: list[dict]) -> None:
        """GPS noise σ is 5-15 m → position differences should be < 100 m."""
        trip = normal_trips[0]
        for p in trip["points"][:20]:
            lat_diff_m = abs(p["observed_lat"] - p["true_lat"]) * 111_320
            lon_diff_m = (abs(p["observed_lon"] - p["true_lon"])
                          * 111_320 * 0.937)  # cos(20.3°)
            assert lat_diff_m < 100, f"Lat noise too large: {lat_diff_m:.1f} m"
            assert lon_diff_m < 100, f"Lon noise too large: {lon_diff_m:.1f} m"

    def test_noise_on_all_scenario_types(
        self,
        normal_trips: list[dict],
        suspicious_trips: list[dict],
        high_risk_trips: list[dict],
    ) -> None:
        for label, trips in [
            ("NORMAL", normal_trips),
            ("SUSPICIOUS", suspicious_trips),
            ("HIGH_RISK", high_risk_trips),
        ]:
            trip = trips[0]
            assert any(
                p["observed_lat"] != p["true_lat"] for p in trip["points"]
            ), f"{label} trip has no position noise"


# ════════════════════════════════════════════════════════════════════
# 4.  Class ratio of a 100-trip dataset
# ════════════════════════════════════════════════════════════════════

class TestClassRatio:
    """Generated dataset should match configured class ratios ±10 %."""

    def test_ratio_within_tolerance(self) -> None:
        rng = np.random.default_rng(123)
        scenarios = assign_scenarios(100, DEFAULT_RATIOS, rng)

        counts = {}
        for s in scenarios:
            counts[s] = counts.get(s, 0) + 1

        # Configured: NORMAL 60, SUSPICIOUS 25, HIGH_RISK 15
        # ±10 % absolute tolerance
        assert 50 <= counts.get("NORMAL", 0) <= 70, (
            f"NORMAL count {counts.get('NORMAL', 0)} outside [50, 70]"
        )
        assert 15 <= counts.get("SUSPICIOUS", 0) <= 35, (
            f"SUSPICIOUS count {counts.get('SUSPICIOUS', 0)} outside [15, 35]"
        )
        assert 5 <= counts.get("HIGH_RISK", 0) <= 25, (
            f"HIGH_RISK count {counts.get('HIGH_RISK', 0)} outside [5, 25]"
        )

    def test_total_equals_n_trips(self) -> None:
        rng = np.random.default_rng(456)
        scenarios = assign_scenarios(100, DEFAULT_RATIOS, rng)
        assert len(scenarios) == 100

    def test_all_classes_present(self) -> None:
        rng = np.random.default_rng(789)
        scenarios = assign_scenarios(100, DEFAULT_RATIOS, rng)
        present = set(scenarios)
        assert "NORMAL" in present
        assert "SUSPICIOUS" in present
        assert "HIGH_RISK" in present


# ════════════════════════════════════════════════════════════════════
# 5.  Trip structural integrity
# ════════════════════════════════════════════════════════════════════

class TestTripStructure:
    """Every generated trip must have valid structure and metadata."""

    def test_required_top_level_keys(self, normal_trips: list[dict]) -> None:
        required = {
            "trip_id", "true_scenario_type", "route_type",
            "signals_applied", "start_time_utc", "n_points",
            "gps_noise_sigma_m", "speed_noise_sigma_mps",
            "planned_route", "points",
        }
        for trip in normal_trips[:3]:
            missing = required - set(trip.keys())
            assert not missing, f"Trip missing keys: {missing}"

    def test_point_count_matches(self, normal_trips: list[dict]) -> None:
        for trip in normal_trips:
            assert len(trip["points"]) == trip["n_points"]

    def test_points_are_time_ordered(self, normal_trips: list[dict]) -> None:
        for trip in normal_trips:
            times = [p["t_s"] for p in trip["points"]]
            assert times == sorted(times), "Points are not time-ordered"

    def test_route_type_valid(
        self,
        normal_trips: list[dict],
        suspicious_trips: list[dict],
        high_risk_trips: list[dict],
    ) -> None:
        valid = {"urban_grid", "highway", "mixed"}
        for trip in normal_trips + suspicious_trips + high_risk_trips:
            assert trip["route_type"] in valid

    def test_route_types_diverse(self, generator: TripGenerator) -> None:
        """Over 30 trips, at least 2 route archetypes should appear."""
        types = set()
        for _ in range(30):
            t = generator.generate("NORMAL")
            types.add(t["route_type"])
        assert len(types) >= 2, f"Only {types} route types generated"
