"""
Trip Guardian ML — Synthetic trip generator.

Generates ONE synthetic trip as a time-ordered sequence of raw GPS
points (lat, lon, timestamp, speed) plus a parallel *true-signal*
series (true deviation, true stop state) **before** noise is added.
Gaussian GPS jitter and speed sensor noise are then applied to produce
the *observed* series.

This module produces **raw per-point time series only**.  Window-level
aggregate features are computed in Phase 5 (feature engineering).
"""

from __future__ import annotations

import math
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import yaml

# ── Constants ───────────────────────────────────────────────────────
POINT_INTERVAL_S = 5.0          # seconds between consecutive GPS fixes
STOP_SPEED_THRESH_MPS = 0.5     # below this → "stopped"
REF_LAT = 20.296                # reference latitude  (Bhubaneswar, IN)
REF_LON = 85.824                # reference longitude
M_PER_DEG_LAT = 111_320.0      # metres per degree of latitude

# Speed ranges per route archetype (m/s)
_SPEED_RANGES: Dict[str, Tuple[float, float]] = {
    "urban_grid": (7.0, 12.5),   # 25–45 km/h
    "highway":    (19.4, 30.6),  # 70–110 km/h
    "mixed":      (11.1, 22.2),  # 40–80 km/h
}

ROUTE_TYPES = list(_SPEED_RANGES.keys())


class TripGenerator:
    """Generate a single synthetic trip with true + observed GPS data."""

    def __init__(self, config_dir: Path | str, seed: int | None = None):
        config_dir = Path(config_dir)
        self.configs: Dict[str, dict] = {}
        for name, fname in [("NORMAL", "normal.yaml"),
                            ("SUSPICIOUS", "suspicious.yaml"),
                            ("HIGH_RISK", "high_risk.yaml")]:
            self.configs[name] = yaml.safe_load(
                (config_dir / fname).read_text(encoding="utf-8")
            )
        self.rng = np.random.default_rng(seed)

    # ================================================================
    #  Public API
    # ================================================================

    def generate(self, scenario_type: str) -> dict:
        """Return a complete trip dict for the given scenario type."""
        if scenario_type not in self.configs:
            raise ValueError(f"Unknown scenario: {scenario_type}")

        # 1. Trip dimensions
        n_points = int(self.rng.integers(120, 481))      # 10-40 min
        start_hour = int(self.rng.integers(0, 24))
        start_dt = datetime(
            2026, 6, int(self.rng.integers(1, 29)),
            start_hour, int(self.rng.integers(0, 60)),
            tzinfo=timezone.utc,
        )

        # 2. Route geometry
        route_type = str(self.rng.choice(ROUTE_TYPES))
        lo, hi = _SPEED_RANGES[route_type]
        base_speed = float(self.rng.uniform(lo, hi))
        target_len = base_speed * n_points * POINT_INTERVAL_S * 1.1
        waypoints = self._make_route(route_type, target_len)

        # 3. Scenario overlays
        deviations, speed_mods, stop_flags, signals = self._apply_scenario(
            scenario_type, n_points, start_hour,
        )

        # 4. Walk the route
        points = self._build_trajectory(
            waypoints, base_speed, n_points, speed_mods, stop_flags, deviations,
        )

        # 5. Sensor noise
        gps_sigma = float(self.rng.uniform(5.0, 15.0))
        speed_sigma = float(self.rng.uniform(0.278, 0.556))  # 1-2 km/h
        self._apply_noise(points, gps_sigma, speed_sigma)

        # 6. Package
        return self._package(
            points, scenario_type, route_type, signals,
            waypoints, gps_sigma, speed_sigma, start_dt,
        )

    # ================================================================
    #  Route generation  (3 archetypes)
    # ================================================================

    def _make_route(self, route_type: str, target_len: float) -> List[Tuple[float, float]]:
        if route_type == "urban_grid":
            return self._urban_route(target_len)
        if route_type == "highway":
            return self._highway_route(target_len)
        return self._mixed_route(target_len)

    def _urban_route(self, target_len: float) -> List[Tuple[float, float]]:
        """Grid-like path with ~90° turns."""
        wps: List[Tuple[float, float]] = [(0.0, 0.0)]
        remaining = target_len
        dirs = [(1, 0), (0, 1), (-1, 0), (0, 1)]
        i = 0
        while remaining > 50:
            d = dirs[i % len(dirs)]
            seg = min(float(self.rng.uniform(200, 800)), remaining)
            last = wps[-1]
            wps.append((last[0] + d[0] * seg, last[1] + d[1] * seg))
            remaining -= seg
            i += 1
        return wps

    def _highway_route(self, target_len: float) -> List[Tuple[float, float]]:
        """Mostly straight with gentle curves."""
        wps: List[Tuple[float, float]] = [(0.0, 0.0)]
        remaining = target_len
        bearing = float(self.rng.uniform(0, 2 * math.pi))
        while remaining > 50:
            seg = min(float(self.rng.uniform(3000, 12000)), remaining)
            bearing += float(self.rng.normal(0, 0.15))
            last = wps[-1]
            wps.append((last[0] + seg * math.cos(bearing),
                        last[1] + seg * math.sin(bearing)))
            remaining -= seg
        return wps

    def _mixed_route(self, target_len: float) -> List[Tuple[float, float]]:
        """Urban start → highway middle → urban end."""
        wps: List[Tuple[float, float]] = [(0.0, 0.0)]
        splits = [0.3, 0.4, 0.3]
        # Urban-1
        rem = target_len * splits[0]
        i = 0
        while rem > 50:
            d = [(1, 0), (0, 1)][i % 2]
            seg = min(float(self.rng.uniform(200, 600)), rem)
            last = wps[-1]
            wps.append((last[0] + d[0] * seg, last[1] + d[1] * seg))
            rem -= seg; i += 1
        # Highway
        rem = target_len * splits[1]
        bearing = float(self.rng.uniform(0, 2 * math.pi))
        while rem > 50:
            seg = min(float(self.rng.uniform(2000, 8000)), rem)
            bearing += float(self.rng.normal(0, 0.1))
            last = wps[-1]
            wps.append((last[0] + seg * math.cos(bearing),
                        last[1] + seg * math.sin(bearing)))
            rem -= seg
        # Urban-2
        rem = target_len * splits[2]
        i = 0
        while rem > 50:
            d = [(0, 1), (1, 0)][i % 2]
            seg = min(float(self.rng.uniform(200, 600)), rem)
            last = wps[-1]
            wps.append((last[0] + d[0] * seg, last[1] + d[1] * seg))
            rem -= seg; i += 1
        return wps

    # ================================================================
    #  Trajectory building
    # ================================================================

    def _build_trajectory(
        self,
        waypoints: List[Tuple[float, float]],
        base_speed: float,
        n_points: int,
        speed_mods: np.ndarray,
        stop_flags: np.ndarray,
        deviations: np.ndarray,
    ) -> List[dict]:
        """Walk along the route applying speed/stop/deviation overlays."""
        # Pre-compute route segments
        segments: List[dict] = []
        cum = 0.0
        for i in range(len(waypoints) - 1):
            dx = waypoints[i + 1][0] - waypoints[i][0]
            dy = waypoints[i + 1][1] - waypoints[i][1]
            sl = math.hypot(dx, dy)
            hd = math.degrees(math.atan2(dx, dy)) % 360
            segments.append(dict(sx=waypoints[i][0], sy=waypoints[i][1],
                                 dx=dx, dy=dy, length=sl, heading=hd, cum=cum))
            cum += sl
        total_len = cum if cum > 0 else 1.0

        dist_along = 0.0
        pts: List[dict] = []
        for i in range(n_points):
            spd = 0.0 if stop_flags[i] else base_speed * float(speed_mods[i])
            spd = max(0.0, spd)
            if spd > 0:
                dist_along += spd * POINT_INTERVAL_S
            dist_along = min(dist_along, total_len)

            bx, by, hd = self._pos_on_route(segments, dist_along, total_len)

            dev = float(deviations[i])
            h_rad = math.radians(hd)
            tx = bx + dev * math.cos(h_rad)
            ty = by - dev * math.sin(h_rad)

            pts.append(dict(
                idx=i, time_s=i * POINT_INTERVAL_S,
                true_x=tx, true_y=ty,
                true_speed_mps=spd,
                true_heading_deg=hd,
                true_deviation_m=abs(dev),
                true_is_stopped=bool(stop_flags[i]),
                route_progress=dist_along / total_len,
            ))

        # Re-derive headings from consecutive true positions
        for i in range(1, len(pts)):
            dx = pts[i]["true_x"] - pts[i - 1]["true_x"]
            dy = pts[i]["true_y"] - pts[i - 1]["true_y"]
            if math.hypot(dx, dy) > 0.1:
                pts[i]["true_heading_deg"] = math.degrees(math.atan2(dx, dy)) % 360
        return pts

    @staticmethod
    def _pos_on_route(segments: List[dict], dist: float,
                      total_len: float) -> Tuple[float, float, float]:
        rem = dist
        for seg in segments:
            if rem <= seg["length"]:
                f = rem / seg["length"] if seg["length"] > 0 else 0
                return (seg["sx"] + f * seg["dx"],
                        seg["sy"] + f * seg["dy"],
                        seg["heading"])
            rem -= seg["length"]
        last = segments[-1]
        return (last["sx"] + last["dx"],
                last["sy"] + last["dy"],
                last["heading"])

    # ================================================================
    #  Scenario overlay dispatch
    # ================================================================

    def _apply_scenario(
        self, scenario_type: str, n: int, start_hour: int,
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray, List[str]]:
        if scenario_type == "NORMAL":
            return self._scenario_normal(n)
        if scenario_type == "SUSPICIOUS":
            return self._scenario_suspicious(n, start_hour)
        return self._scenario_high_risk(n, start_hour)

    # ── NORMAL ──────────────────────────────────────────────────────

    def _scenario_normal(self, n: int):
        cfg = self.configs["NORMAL"]
        dc = cfg["deviation"]

        # Smooth deviation random-walk around a lognormal baseline
        mu_log = math.log(dc["mean_m"]) - dc["spread"] ** 2 / 2
        baseline = float(self.rng.lognormal(mu_log, dc["spread"]))
        step_sig = baseline * 0.15

        raw = np.empty(n)
        raw[0] = baseline
        for i in range(1, n):
            raw[i] = raw[i - 1] + 0.05 * (baseline - raw[i - 1]) + self.rng.normal(0, step_sig)
            raw[i] = max(0.0, raw[i])
            if raw[i] > dc["self_correct_threshold_m"]:
                raw[i] *= dc["self_correct_decay"]

        devs = self._ema(raw, 0.15)
        devs *= float(self.rng.choice([-1.0, 1.0]))

        # Speed
        var = cfg["speed"]["variation_pct"] / 100.0
        sp = 1.0 + self.rng.uniform(-var, var, n)
        ratio = float(self.rng.uniform(cfg["duration_ratio"]["min"],
                                       cfg["duration_ratio"]["max"]))
        sp /= ratio

        # Stops
        stops = np.zeros(n, dtype=bool)
        ns = int(self.rng.integers(cfg["stops"]["count_min"],
                                   cfg["stops"]["count_max"] + 1))
        for _ in range(ns):
            dur = float(self.rng.uniform(cfg["stops"]["duration_min_s"],
                                         cfg["stops"]["duration_max_s"]))
            dur_pts = max(1, int(dur / POINT_INTERVAL_S))
            lo = n // 5
            hi = max(lo + 1, 4 * n // 5)
            st = int(self.rng.integers(lo, hi))
            stops[st:min(st + dur_pts, n)] = True

        sp = np.where(stops, 0.0, sp)
        return devs, sp, stops, ["baseline"]

    # ── SUSPICIOUS ──────────────────────────────────────────────────

    def _scenario_suspicious(self, n: int, start_hour: int):
        cfg = self.configs["SUSPICIOUS"]

        # Night boost
        nb = cfg["night_boost"]
        boost = 1.0
        if start_hour >= nb["start_hour"] or start_hour < nb["end_hour"]:
            boost = 1.0 + nb["magnitude_shift_pct"] / 100.0

        # Baseline deviation
        bc = cfg["baseline_deviation"]
        bl = float(self.rng.lognormal(
            math.log(bc["mean_m"]) - bc["spread"] ** 2 / 2, bc["spread"]))
        raw = np.abs(self.rng.normal(bl, bl * 0.2, n))
        devs = self._ema(raw, 0.1) * float(self.rng.choice([-1.0, 1.0]))
        side = 1.0 if devs.mean() >= 0 else -1.0

        sp = 1.0 + self.rng.uniform(-0.05, 0.05, n)
        stops = np.zeros(n, dtype=bool)

        # Pick anomalies
        anames = list(cfg["anomalies"].keys())
        pick = int(self.rng.integers(cfg["anomaly_pick_count"]["min"],
                                     cfg["anomaly_pick_count"]["max"] + 1))
        chosen = list(self.rng.choice(anames, min(pick, len(anames)), replace=False))
        starts = self._place_events(n, len(chosen))

        for aname, es in zip(chosen, starts):
            ac = cfg["anomalies"][aname]
            if aname == "sustained_deviation":
                dur = int(self.rng.uniform(ac["duration_min_s"],
                                           ac["duration_max_s"]) / POINT_INTERVAL_S)
                mag = float(self.rng.lognormal(
                    math.log(ac["deviation_mean_m"]) - ac["deviation_spread"] ** 2 / 2,
                    ac["deviation_spread"])) * boost
                env = self._trapezoid(dur)
                end = min(es + dur, n)
                devs[es:end] = mag * env[:end - es] * side

            elif aname == "off_route_stop":
                dur = int(self.rng.uniform(ac["stop_duration_min_s"],
                                           ac["stop_duration_max_s"]) / POINT_INTERVAL_S)
                off = float(self.rng.uniform(ac["off_route_min_m"],
                                             ac["off_route_max_m"])) * boost
                end = min(es + dur, n)
                stops[es:end] = True
                sp[es:end] = 0.0
                devs[es:end] = off * side

            elif aname == "speed_drop":
                dur = int(self.rng.uniform(ac["sustained_min_s"],
                                           ac["sustained_max_s"]) / POINT_INTERVAL_S)
                drop = float(self.rng.uniform(ac["drop_pct_min"],
                                              ac["drop_pct_max"])) / 100.0
                end = min(es + dur, n)
                sp[es:end] *= (1.0 - drop)

            elif aname == "deviate_return_cycles":
                nc = int(self.rng.integers(ac["cycle_count_min"],
                                           ac["cycle_count_max"] + 1))
                cdur = int(self.rng.uniform(ac["cycle_duration_min_s"],
                                            ac["cycle_duration_max_s"]) / POINT_INTERVAL_S)
                for c in range(nc):
                    cs = es + c * (cdur + 4)
                    if cs + cdur > n:
                        break
                    mag = float(self.rng.uniform(ac["deviation_min_m"],
                                                 ac["deviation_max_m"])) * boost
                    env = self._trapezoid(cdur)
                    end = min(cs + cdur, n)
                    devs[cs:end] = mag * env[:end - cs] * side

        sp = np.where(stops, 0.0, sp)
        return devs, sp, stops, chosen

    # ── HIGH_RISK ───────────────────────────────────────────────────

    def _scenario_high_risk(self, n: int, start_hour: int):
        cfg = self.configs["HIGH_RISK"]

        nb = cfg["night_boost"]
        boost = 1.0
        if start_hour >= nb["start_hour"] or start_hour < nb["end_hour"]:
            boost = 1.0 + nb["magnitude_shift_pct"] / 100.0

        bc = cfg["baseline_deviation"]
        bl = float(self.rng.lognormal(
            math.log(bc["mean_m"]) - bc["spread"] ** 2 / 2, bc["spread"]))
        raw = np.abs(self.rng.normal(bl, bl * 0.3, n))
        devs = self._ema(raw, 0.1) * float(self.rng.choice([-1.0, 1.0]))
        side = 1.0 if devs.mean() >= 0 else -1.0

        sp = 1.0 + self.rng.uniform(-0.05, 0.05, n)
        stops = np.zeros(n, dtype=bool)

        # Pick >= 2 anomalies; excessive_duration never alone
        anames = list(cfg["anomalies"].keys())
        pick = int(self.rng.integers(cfg["anomaly_pick_count"]["min"],
                                     cfg["anomaly_pick_count"]["max"] + 1))
        chosen = list(self.rng.choice(anames, min(pick, len(anames)), replace=False))

        if set(chosen) == {"excessive_duration"}:
            others = [a for a in anames if a != "excessive_duration"]
            chosen.append(str(self.rng.choice(others)))
        while len(chosen) < 2:
            rem = [a for a in anames if a not in chosen]
            if not rem:
                break
            chosen.append(str(self.rng.choice(rem)))

        local = [a for a in chosen if a != "excessive_duration"]
        starts = self._place_events(n, len(local))

        for aname, es in zip(local, starts):
            ac = cfg["anomalies"][aname]

            if aname == "large_sustained_deviation":
                dur = int(self.rng.uniform(ac["duration_min_s"],
                                           ac["duration_max_s"]) / POINT_INTERVAL_S)
                mag = float(self.rng.uniform(ac["deviation_min_m"],
                                             ac["deviation_max_m"])) * boost
                end = min(es + dur, n)
                ramp = max(1, dur // 6)
                for j in range(min(ramp, end - es)):
                    devs[es + j] = mag * (j / ramp) * side
                for j in range(ramp, end - es):
                    devs[es + j] = mag * side  # sustains, never corrects

            elif aname == "prolonged_stop":
                dur = int(self.rng.uniform(ac["duration_min_s"],
                                           ac["duration_max_s"]) / POINT_INTERVAL_S)
                off = float(self.rng.uniform(ac["off_route_min_m"],
                                             ac["off_route_max_m"])) * boost
                end = min(es + dur, n)
                stops[es:end] = True
                sp[es:end] = 0.0
                devs[es:end] = off * side

            elif aname == "multiple_deviations":
                ne = int(self.rng.integers(ac["episode_count_min"],
                                           ac["episode_count_max"] + 1))
                edur = int(self.rng.uniform(ac["episode_duration_min_s"],
                                            ac["episode_duration_max_s"]) / POINT_INTERVAL_S)
                raw_mags = np.sort(self.rng.uniform(ac["deviation_min_m"],
                                                    ac["deviation_max_m"],
                                                    size=ne))
                for e in range(ne):
                    ecs = es + e * (edur + 4)
                    if ecs + edur > n:
                        break
                    mag = float(raw_mags[e]) * boost
                    env = self._trapezoid(edur)
                    end = min(ecs + edur, n)
                    devs[ecs:end] = mag * env[:end - ecs] * side

            elif aname == "high_speed_variance":
                dur = max(10, n // 3)
                end = min(es + dur, n)
                lo_osc = ac["speed_oscillation_min"]
                hi_osc = ac["speed_oscillation_max"]
                for j in range(es, end):
                    sp[j] *= float(self.rng.uniform(lo_osc, hi_osc))
                if ac.get("combined_with_deviation", False):
                    min_d = ac.get("min_deviation_m", 100)
                    for j in range(es, end):
                        if abs(devs[j]) < min_d:
                            devs[j] = min_d * side * boost

        # Global: excessive_duration
        if "excessive_duration" in chosen:
            edc = cfg["anomalies"]["excessive_duration"]
            ratio = float(self.rng.uniform(edc["ratio_min"], edc["ratio_max"]))
            mask = ~stops
            sp[mask] /= ratio

        sp = np.where(stops, 0.0, sp)
        return devs, sp, stops, chosen

    # ================================================================
    #  Helpers
    # ================================================================

    @staticmethod
    def _trapezoid(n: int, up: float = 0.15, down: float = 0.15) -> np.ndarray:
        if n <= 0:
            return np.array([])
        env = np.ones(n)
        ru = max(1, int(n * up))
        rd = max(1, int(n * down))
        env[:ru] = np.linspace(0, 1, ru)
        env[n - rd:] = np.linspace(1, 0, rd)
        return env

    @staticmethod
    def _ema(arr: np.ndarray, alpha: float) -> np.ndarray:
        out = np.empty_like(arr, dtype=float)
        out[0] = arr[0]
        for i in range(1, len(arr)):
            out[i] = alpha * arr[i] + (1 - alpha) * out[i - 1]
        return out

    def _place_events(self, n: int, k: int) -> List[int]:
        if k == 0:
            return []
        margin = max(10, n // 10)
        usable = max(1, n - 2 * margin)
        sec = max(1, usable // k)
        out: List[int] = []
        for i in range(k):
            base = margin + i * sec
            jitter = int(self.rng.integers(0, max(1, sec // 3)))
            out.append(min(base + jitter, n - 1))
        return out

    # ================================================================
    #  Noise injection
    # ================================================================

    def _apply_noise(self, points: List[dict],
                     gps_sigma: float, speed_sigma: float) -> None:
        for p in points:
            p["obs_x"] = p["true_x"] + float(self.rng.normal(0, gps_sigma))
            p["obs_y"] = p["true_y"] + float(self.rng.normal(0, gps_sigma))
            p["obs_speed_mps"] = max(
                0.0, p["true_speed_mps"] + float(self.rng.normal(0, speed_sigma))
            )

    # ================================================================
    #  Coordinate conversion & output packaging
    # ================================================================

    def _to_latlon(self, x: float, y: float) -> Tuple[float, float]:
        lat = REF_LAT + y / M_PER_DEG_LAT
        lon = REF_LON + x / (M_PER_DEG_LAT * math.cos(math.radians(REF_LAT)))
        return round(lat, 7), round(lon, 7)

    def _package(
        self, points: List[dict], scenario: str, route_type: str,
        signals: List[str], waypoints: List[Tuple[float, float]],
        gps_sigma: float, speed_sigma: float, start_dt: datetime,
    ) -> dict:
        fmt: List[dict] = []
        for p in points:
            tlat, tlon = self._to_latlon(p["true_x"], p["true_y"])
            olat, olon = self._to_latlon(p["obs_x"], p["obs_y"])
            ts = start_dt + timedelta(seconds=p["time_s"])
            fmt.append(dict(
                idx=p["idx"],
                t_s=p["time_s"],
                timestamp_utc=ts.isoformat(),
                true_lat=tlat, true_lon=tlon,
                true_speed_mps=round(p["true_speed_mps"], 3),
                true_heading_deg=round(p["true_heading_deg"], 1),
                true_deviation_m=round(p["true_deviation_m"], 2),
                true_is_stopped=p["true_is_stopped"],
                observed_lat=olat, observed_lon=olon,
                observed_speed_mps=round(p["obs_speed_mps"], 3),
            ))

        route_ll = [self._to_latlon(wx, wy) for wx, wy in waypoints]
        return dict(
            trip_id=str(uuid.uuid4()),
            true_scenario_type=scenario,
            route_type=route_type,
            signals_applied=signals,
            start_time_utc=start_dt.isoformat(),
            n_points=len(fmt),
            gps_noise_sigma_m=round(gps_sigma, 2),
            speed_noise_sigma_mps=round(speed_sigma, 4),
            planned_route=route_ll,
            points=fmt,
        )
