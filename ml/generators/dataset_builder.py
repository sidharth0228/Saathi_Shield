"""
Trip Guardian ML — Dataset builder.

Orchestrates generating N synthetic trips with a configurable class
ratio, writes one JSON file per trip into ``ml/data/raw/dataset_v1/``,
and produces a ``manifest.json`` summarising generation parameters.

Usage (from the project root)::

    python -m ml.generators.dataset_builder --n_trips 500
    python -m ml.generators.dataset_builder --n_trips 100 --seed 42
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

# Allow running as a standalone script *and* as ``python -m …``
_THIS_DIR = Path(__file__).resolve().parent
_PROJECT_ROOT = _THIS_DIR.parents[1]          # Saathi_Shield/
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from ml.generators.trip_generator import TripGenerator  # noqa: E402

# ── Defaults ────────────────────────────────────────────────────────
DEFAULT_RATIOS = {"NORMAL": 0.60, "SUSPICIOUS": 0.25, "HIGH_RISK": 0.15}
DEFAULT_OUTPUT_DIR = _THIS_DIR.parent / "data" / "raw" / "dataset_v1"
DEFAULT_CONFIG_DIR = _THIS_DIR / "scenario_configs"


def assign_scenarios(
    n_trips: int,
    ratios: dict[str, float],
    rng,
) -> list[str]:
    """Return a shuffled list of *n_trips* scenario-type labels."""
    assignments: list[str] = []
    for scenario, ratio in ratios.items():
        assignments.extend([scenario] * int(round(n_trips * ratio)))

    # Pad / trim to exactly n_trips (rounding artefacts)
    while len(assignments) < n_trips:
        assignments.append("NORMAL")
    assignments = assignments[:n_trips]

    indices = rng.permutation(len(assignments))
    return [assignments[int(i)] for i in indices]


def build_dataset(
    n_trips: int,
    ratios: dict[str, float],
    output_dir: Path,
    config_dir: Path,
    seed: int | None,
) -> Path:
    """Generate *n_trips* trip files and a manifest.  Returns *output_dir*."""
    import numpy as np

    rng = np.random.default_rng(seed)
    gen = TripGenerator(config_dir, seed=seed)

    output_dir.mkdir(parents=True, exist_ok=True)

    scenarios = assign_scenarios(n_trips, ratios, rng)
    class_counter: Counter = Counter()
    route_counter: Counter = Counter()

    t0 = time.time()

    for i, scenario in enumerate(scenarios):
        trip = gen.generate(scenario)

        # Write trip file
        fname = f"trip_{i:05d}_{trip['trip_id'][:8]}.json"
        fpath = output_dir / fname
        fpath.write_text(json.dumps(trip, indent=None, separators=(",", ":")),
                         encoding="utf-8")

        class_counter[scenario] += 1
        route_counter[trip["route_type"]] += 1

        if (i + 1) % 50 == 0 or i + 1 == n_trips:
            elapsed = time.time() - t0
            print(f"  [{i+1:>5}/{n_trips}]  {elapsed:6.1f}s", flush=True)

    # ── Manifest ────────────────────────────────────────────────────
    actual_ratios = {k: round(v / n_trips, 4) for k, v in class_counter.items()}
    manifest = {
        "dataset_version": "v1",
        "is_synthetic": True,
        "generation_timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "total_trips": n_trips,
        "class_counts": dict(class_counter),
        "class_ratios_configured": ratios,
        "class_ratios_actual": actual_ratios,
        "route_type_counts": dict(route_counter),
        "point_interval_s": 5.0,
        "gps_noise_sigma_m_range": [5, 15],
        "speed_noise_sigma_kmh_range": [1, 2],
        "rng_seed": seed,
    }

    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"\n[OK] Dataset written to {output_dir}")
    print(f"    Trips : {n_trips}")
    print(f"    Classes: {dict(class_counter)}")
    print(f"    Routes : {dict(route_counter)}")
    print(f"    Manifest: {manifest_path}")
    return output_dir


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a synthetic Trip Guardian dataset.",
    )
    parser.add_argument("--n_trips", type=int, required=True,
                        help="Number of trips to generate.")
    parser.add_argument("--seed", type=int, default=None,
                        help="RNG seed for reproducibility.")
    parser.add_argument("--output_dir", type=str, default=None,
                        help="Output directory (default: ml/data/raw/dataset_v1/).")
    parser.add_argument("--config_dir", type=str, default=None,
                        help="Scenario config directory.")
    parser.add_argument("--ratio_normal", type=float, default=0.60)
    parser.add_argument("--ratio_suspicious", type=float, default=0.25)
    parser.add_argument("--ratio_high_risk", type=float, default=0.15)
    args = parser.parse_args()

    ratios = {
        "NORMAL": args.ratio_normal,
        "SUSPICIOUS": args.ratio_suspicious,
        "HIGH_RISK": args.ratio_high_risk,
    }
    total = sum(ratios.values())
    if abs(total - 1.0) > 0.01:
        parser.error(f"Class ratios must sum to ~1.0, got {total:.3f}")

    out = Path(args.output_dir) if args.output_dir else DEFAULT_OUTPUT_DIR
    cfg = Path(args.config_dir) if args.config_dir else DEFAULT_CONFIG_DIR

    build_dataset(args.n_trips, ratios, out, cfg, args.seed)


if __name__ == "__main__":
    main()
