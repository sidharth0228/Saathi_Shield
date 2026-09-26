# Saathi Shield - AI-Powered Personal Safety & Emergency Response Platform

Saathi Shield is a production-grade, highly scalable personal safety ecosystem designed for women, men, senior citizens, children, and medical emergencies. The platform integrates proactive AI threat detection, audio distress recognition, smart travel monitoring, and instant location-aware community response dispatches.

---

## 📄 Design & Architecture Documentation (Phase 1)

Detailed blueprints and API contracts are available in the following files:

1. **System Architecture**: Detailed blocks, interaction flows, sequence diagrams, AI models pipelines, and AWS deployment layouts.
   * [system_architecture.md](file:///c:/Users/SIDHARTH/OneDrive/Desktop/Saathi_Shield/docs/system_architecture.md)
2. **Database Schema**: Comprehensive database table parameters, relationships, data-types, and indexing strategies.
   * [database_schema.md](file:///c:/Users/SIDHARTH/OneDrive/Desktop/Saathi_Shield/docs/database_schema.md)
3. **API Specifications**: Complete listing of REST API endpoints, JWT authentication schemes, file upload protocols, and real-time WebSocket messaging formats.
   * [api_specifications.md](file:///c:/Users/SIDHARTH/OneDrive/Desktop/Saathi_Shield/docs/api_specifications.md)

---

## 🛠️ Repository Layout (Planned)

The project will be organized as follows:

```text
Saathi_Shield/
├── docs/                             # Phase 1 Documentation
│   ├── system_architecture.md
│   ├── database_schema.md
│   └── api_specifications.md
├── backend/                          # Phase 2 Django API
│   ├── manage.py
│   ├── saathi_shield/                 # Project Settings
│   ├── apps/                         # App Modules
│   │   ├── authentication/
│   │   ├── travel/
│   │   ├── alerts/
│   │   ├── community/
│   │   └── ai_engine/
│   ├── celery_app.py
│   └── requirements.txt
├── mobile/                           # Phase 3 Flutter App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── blocs/
│   │   ├── models/
│   │   ├── services/
│   │   └── screens/
│   └── pubspec.yaml
├── ai_models/                        # Phase 4 ML Notebooks & Scripts
│   ├── models/                       # Stored model weights
│   ├── threat_detector/
│   └── distress_detector/
└── deployment/                       # Phase 5 Configs
    ├── Dockerfile.backend
    ├── docker-compose.yml
    └── nginx/
```

---

## 🚀 Key Feature Sets

* **One-Tap SOS System**: Instant high-priority alert dispatching containing current GPS coordinate telemetry, battery level, network status, and tracking tokens.
* **Proactive Travel Protection**: Periodically checks paths for deviations or delays. If anomalies cross limits, confirmation triggers. If unanswered, SOS escalates automatically.
* **AI Threat Detection & Distress Listener**: Multi-modal analytics predicting route danger scores and classifying environment audio for screams or crying indicators.
* **Community Dispatch Network**: Identifies nearby registered responders using PostGIS coordinate indexing, dispatching assistance warnings with navigation interfaces.
* **Evidence Protection**: Client-side AES encrypted media streams uploaded in sequential blocks to secure S3 vaults.
* **Siren & Hardware strobe**: Immediate flashlight toggles, max screen lighting, and loud audible frequencies.
* **Elderly Fall Detection**: Continual acceleration evaluation with automatic SOS triggers upon impact sequences.
* **Medical Emergency Profile**: Shares preconfigured allergies, blood types, and medical conditions with dispatchers on demand.
