# Saathi Shield — Trip Guardian ML

> **Status**: Phase 1 — Problem Definition (documentation only)
> **Last updated**: 2026-09-26
> **Owner**: @sidharth0228

---

## 1  ML Objective

Build a **3-class behavioural-risk classifier** that scores 60-second trip
windows emitted by the Safe Travel Mode subsystem.

| Class label    | Numeric range | Meaning                                                                 |
|----------------|---------------|-------------------------------------------------------------------------|
| `NORMAL`       | 0 – 35        | Traveller is following the planned route at expected speed.              |
| `SUSPICIOUS`   | 36 – 70       | Anomalous deviation, unusual stop, or late-night walk in a low-density area. |
| `HIGH_RISK`    | 71 – 100      | Prolonged deviation + stop + no user confirmation, or impact signature. |

### Input features (per 60-second window)

| Feature group   | Examples                                                                  |
|-----------------|---------------------------------------------------------------------------|
| **Spatial**     | Cross-track error (m), cumulative off-route distance, crime-density index |
| **Temporal**    | Hour-of-day (sine/cosine encoded), day-of-week, holiday flag             |
| **Behavioural** | Mean speed, speed variance, stop duration, heading change rate            |

### Output

A single record per window:

```json
{
  "window_id": "uuid",
  "session_id": "uuid",
  "timestamp_utc": "2026-09-26T04:30:00Z",
  "risk_label": "SUSPICIOUS",
  "risk_score": 52.3,
  "feature_vector": { "...": "..." }
}
```

The classifier replaces the current deterministic scoring logic in
[`backend/ai_engine/views.py`](../backend/ai_engine/views.py) with a
learned model, while preserving the same REST contract consumed by the
mobile client.

---

## 2  Explicit Non-Goals

These items are **out of scope** for this subsystem.  Any future change
that would bring them in scope **must** update this README first.

| ❌ Non-goal | Rationale |
|-------------|-----------|
| **Danger detection / emergency verification** | Trip Guardian is a *behavioural-anomaly scorer*, not a danger detector. It does not determine whether an emergency is actually occurring. |
| **Direct SOS triggering** | The classifier feeds a *rule-based escalation pipeline* downstream (anomaly counter → PIN challenge → auto-SOS). It never triggers an SOS on its own. |
| **Audio distress classification** | Audio-based threat detection is handled by a separate acoustic pipeline (see System Architecture §3.2). |
| **Real-time on-device inference** | v1 runs server-side only. On-device (TFLite) export is a potential future phase. |
| **Geofencing or safe-zone management** | Route corridor checks are performed by the existing travel service; the ML model receives their outputs as features. |

---

## 3  Data Provenance — Synthetic Only (v1)

> [!CAUTION]
> **Version 1 uses 100 % synthetic data.**
> All training, validation, and test datasets are generated
> programmatically.  Model outputs have **not** been validated against
> real-world safety outcomes and **must not** be treated as ground-truth
> risk assessments in any production safety-critical decision path without
> additional human-in-the-loop review.

Implications:

* Reported accuracy, precision, and recall metrics reflect performance
  on synthetic distributions **only**.
* The model may exhibit distributional shift when exposed to real sensor
  telemetry; a calibration phase using anonymised field data is planned
  for a future version.
* No Personally Identifiable Information (PII) exists in any dataset
  file in this repository.

---

## 4  Target Project Layout

The folder structure below is the planned organisation for all ML
artefacts.  **Do not create these directories until their corresponding
implementation phase begins.**

```text
ml/
├── README.md                          ← YOU ARE HERE (single source of truth)
│
├── data/
│   ├── generators/
│   │   ├── trip_generator.py          # Synthetic trip-window generator
│   │   └── noise_profiles.py          # Sensor noise & drift models
│   ├── raw/                           # Generated CSV/Parquet datasets
│   ├── processed/                     # Feature-engineered datasets
│   └── splits/                        # train / val / test partitions
│
├── features/
│   ├── feature_registry.py            # Central feature name ↔ dtype registry
│   ├── spatial.py                     # Cross-track error, off-route distance
│   ├── temporal.py                    # Cyclical time encoding, holiday flags
│   └── behavioural.py                 # Speed stats, stop detection, heading Δ
│
├── models/
│   ├── baseline/
│   │   └── rule_based.py              # Reimplementation of current heuristic
│   ├── v1/
│   │   ├── train.py                   # Training entry-point
│   │   ├── evaluate.py                # Metrics, confusion matrix, reports
│   │   └── config.yaml                # Hyperparameters & feature toggles
│   └── registry/                      # Serialised model artefacts (.joblib / .pt)
│
├── serving/
│   ├── predictor.py                   # Inference wrapper consumed by Django
│   └── schema.py                      # Pydantic request / response contracts
│
├── notebooks/
│   ├── 01_eda.ipynb                   # Exploratory data analysis
│   ├── 02_feature_engineering.ipynb   # Feature deep-dives
│   └── 03_model_comparison.ipynb      # Model selection experiments
│
├── tests/
│   ├── test_generators.py
│   ├── test_features.py
│   ├── test_model_inference.py
│   └── conftest.py
│
├── configs/
│   └── default.yaml                   # Global experiment configuration
│
├── scripts/
│   ├── generate_dataset.py            # CLI: end-to-end data generation
│   └── run_training.py                # CLI: full training pipeline
│
├── requirements.txt                   # ML-specific Python dependencies
└── pyproject.toml                     # Project metadata & tool config
```

> [!NOTE]
> Only `ml/` and this `README.md` exist at the end of Phase 1.
> Subsequent phases will populate the directories above incrementally.

---

## 5  Governance

This README is the **single source of truth** for scope, non-goals, and
data provenance of the Trip Guardian ML subsystem.

* Future phases **must not** contradict the boundaries stated here
  without first submitting an update to this file.
* Any scope expansion (e.g., adding audio features, enabling on-device
  inference) requires an explicit amendment to §2 (Non-Goals) before
  implementation work begins.
* Changes to the class taxonomy (§1) require a corresponding migration
  in the downstream rule-based escalation pipeline and the
  [`ThreatAssessment`](../backend/ai_engine/models.py) model.

---

## Appendix A — Relationship to Existing Backend

The current [`RouteSafetyScoreView`](../backend/ai_engine/views.py)
computes risk scores using a deterministic heuristic (coordinate hash →
crime index, time-of-day → illumination, etc.).  Trip Guardian replaces
the scoring logic **inside** that view with a call to `serving/predictor.py`,
preserving the REST response shape:

```text
GET /api/v1/ai/route-safety-score/?lat=...&lng=...
→ { "safety_score": float, "risk_label": str, "factors": dict }
```

The Django view remains the integration boundary; the ML subsystem has
no direct database access and receives pre-assembled feature dicts from
the view layer.
