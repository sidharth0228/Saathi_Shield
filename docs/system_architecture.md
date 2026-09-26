# Saathi Shield - System Architecture Design

This document details the high-level system architecture, real-time communications flow, AI/ML pipelines, mobile hardware integrations, and deployment model for the **Saathi Shield** Personal Safety and Emergency Response Platform.

---

## 1. High-Level Architectural Overview

Saathi Shield uses a distributed, event-driven architecture designed for high availability, low-latency communication, and secure processing of emergency events.

```mermaid
graph TD
    %% Clients
    FlutterApp[Flutter Client App <br> Android / iOS]
    AdminDash[Web Admin Dashboard <br> React/HTML5]

    %% Gateway & Load Balancer
    ALB[AWS Application Load Balancer]

    %% Backend Layer
    DjangoWS[Django Channels <br> WebSocket Server]
    DjangoREST[Django REST Framework <br> HTTP Server]

    %% Cache & Queue
    RedisBroker[(Redis <br> Cache & PubSub Broker)]

    %% Workers
    CeleryWorkers[Celery Workers <br> Async Tasks]

    %% Databases
    PostgreSQL[(PostgreSQL <br> User/App DB + PostGIS)]
    S3[AWS S3 <br> Encrypted Evidence Storage]

    %% AI Modules
    AI_Engine[Python AI Engine <br> PyTorch/TensorFlow / Scikit-Learn]

    %% External Services
    FCM[Firebase Cloud Messaging]
    Twilio[Twilio SMS Gateway]
    SendGrid[Email Gateway]
    ORS[OpenRouteService API]

    %% Connections
    FlutterApp -->|HTTPS / REST| ALB
    FlutterApp -->|WSS / WebSockets| ALB
    AdminDash -->|HTTPS / REST| ALB

    ALB -->|Port 8000 / HTTP| DjangoREST
    ALB -->|Port 8001 / WS| DjangoWS

    DjangoREST --> PostgreSQL
    DjangoWS --> RedisBroker
    DjangoREST --> RedisBroker

    CeleryWorkers <-->|Fetch/Execute Tasks| RedisBroker
    CeleryWorkers --> PostgreSQL
    CeleryWorkers --> S3
    CeleryWorkers <--> AI_Engine

    %% External Service Triggers
    CeleryWorkers --> FCM
    CeleryWorkers --> Twilio
    CeleryWorkers --> SendGrid
    DjangoREST --> ORS
```

### Components Description

1. **Flutter Mobile Application**:
   * **State Management**: BLoC or Provider for structured state updates.
   * **Location Tracker**: Background geolocator plugin running as a background service to monitor user coordinates.
   * **On-Device Fall Detection**: Continuously samples accelerometer/gyroscope signals, filtering out normal movement noise before running thresholding checks.
   * **On-Device Voice Command Recognition**: Employs a lightweight keyword-spotting engine (e.g., PocketSphinx or on-device Speech-To-Text API) to trigger the emergency workflow offline or stream audio for validation.
   * **Evidence Capture System**: Runs concurrent camera and audio capture, splitting the recorded streams into small, encrypted media segments and uploading them to S3.

2. **Django & Django REST Framework (DRF) Web Backend**:
   * Handles user accounts, profile registration, OTP validation, emergency contact definitions, configuration management, and admin views.
   * Provides JSON-formatted REST responses secured via JSON Web Tokens (JWT).

3. **Django Channels (WebSockets)**:
   * Maintains persistent, bi-directional connections to active clients.
   * Handles real-time location stream broadcasts from SOS victims to loved ones and nearby responders.
   * Broadcasts urgent dispatch messages to available community responders.

4. **Redis Cache & Message Broker**:
   * Acts as the Django Channels channel layer backend (pub/sub).
   * Stores temporary, fast-changing geospatial locations (e.g., active responder positions and active travel paths).
   * Manages Celery async task scheduling and message routing.

5. **Celery Workers**:
   * Processes out-of-band operations such as routing calculations, SMS/Push notification alerts, media file packaging, and database cleanups.
   * Regularly fetches government weather/disaster feeds to issue regional alerts.

6. **AI / ML Engine**:
   * **Threat Classifier**: Analyzes historical crime metadata, time of day, location, and speed anomalies to assign a hazard rating.
   * **Acoustic Distress Detector**: Classifies audio inputs to identify screams or aggressive shouting.

7. **Databases**:
   * **PostgreSQL + PostGIS**: Maintains relational tables (users, contacts, travel records, history logs) with GIS extensions for mapping nearest responders.
   * **AWS S3**: An isolated, secure container for storing chunked, client-encrypted evidence media files.

---

## 2. Key Interaction Flows & Sequence Diagrams

### 2.1 One-Tap SOS Activation Sequence

The diagram below details the step-by-step pipeline when a user triggers the main SOS emergency button:

```mermaid
sequenceDiagram
    autonumber
    actor User as User Mobile (Flutter)
    participant Server as DRF / Channels API
    participant Cache as Redis Cache
    participant Queue as Celery Queue
    participant DB as PostgreSQL + PostGIS
    participant SMS as Twilio / Email Gateway
    participant FCM as Firebase Cloud Messaging
    participant Responder as Nearby Responders (Flutter)

    User->>Server: POST /api/v1/sos/trigger/ <br> (lat, lng, battery, trigger_type='ONE_TAP')
    activate Server
    Server->>DB: Save Alert (Status: ACTIVE, Secure Token generated)
    Server->>Cache: Set Alert State & Active Coordinate
    Server->>Queue: Enqueue Notifications (alert_id)
    Server-->>User: 201 Created (alert_id, secure_tracking_url)
    deactivate Server

    %% Background Notifications
    activate Queue
    Queue->>SMS: Dispatch SMS with secure tracking link to Contacts
    Queue->>DB: Look up active responders within 2km (PostGIS spatial query)
    DB-->>Queue: List of responder device tokens
    Queue->>FCM: Dispatch push notifications to emergency contacts & responders
    deactivate Queue

    %% WebSocket Connection
    User->>Server: Connect to WSS /ws/sos/{alert_id}/
    activate Server
    Server-->>User: WS Handshake Accepted

    loop Location Tracking (Every 10-30 seconds)
        User->>Server: WS: Send Coordinate Update (lat, lng)
        Server->>Cache: Update current position in Cache
        Server->>DB: Save coordinate history point
        Server->>Responder: Broadcast updated location to connected dispatchers
    end
    deactivate Server
```

### 2.2 Safe Travel Mode & Deviation Monitoring

The route deviation and anomaly detection workflow operates as a semi-automated guardrail:

```mermaid
sequenceDiagram
    autonumber
    actor User as User Mobile (Flutter)
    participant Server as Django REST API
    participant ORS as OpenRouteService API
    participant AI as AI Threat Engine
    participant Cache as Redis Anomaly Cache
    participant FCM as Push Notification Service

    User->>Server: POST /api/v1/travel/start/ <br> (source_lat, source_lng, dest_lat, dest_lng)
    activate Server
    Server->>ORS: GET /v2/directions/driving-car (route geojson)
    ORS-->>Server: GeoJSON Route coordinates
    Server->>DB: Save TravelSession (Status: ACTIVE, Planned Route)
    Server-->>User: 201 Created (session_id)
    deactivate Server

    loop Travel Verification Ping (Every 60s)
        User->>Server: POST /api/v1/travel/ping/ <br> (session_id, current_lat, current_lng, speed)
        activate Server
        Server->>AI: Evaluate Route Status (current_coords, planned_route, speed, time)
        AI->>AI: Calculate cross-track error (distance to nearest route segment)
        AI-->>Server: Route Status (DEVIATED / COMPLETED / SUSPICIOUS, Anomaly Score)
        
        alt Risk Level is Suspicious / Deviated
            Server->>Cache: Increment anomaly counter (threshold = 3 pings)
            alt Anomaly Counter Exceeded
                Server->>FCM: Send High Priority Push (Request safety PIN confirm)
                Note over User: Phone vibrates/sirens. <br> 60-second countdown begins.
                alt Safety PIN Incorrect or Countdown Expires
                    Server->>Server: Automatically trigger SOS workflow
                    Server->>DB: Save Alert, notify contacts & responders
                end
            end
        end
        Server-->>User: 200 OK (risk_level, status)
        deactivate Server
    end
```

---

## 3. AI Modules & Threat Detection Pipelines

### 3.1 Proactive AI Threat Detection Engine
This module estimates the general risk factor of an area or route. It combines static parameters (time, region) with dynamic behavioral data (route deviation, speed changes).

* **Model Framework**: Python-based Scikit-Learn Random Forest Classifier or LightGBM model.
* **Input Features**:
  1. **Spatial Features**: Crime density index (obtained from historical incident reports), population density grid index.
  2. **Temporal Features**: Time of day (0-24 hour sine/cosine projection), day of the week, holiday flags.
  3. **Behavioral Features**: Cross-track error (meters away from optimal routing), movement velocity deviation (unusual stops, walking vs. vehicle mismatch).
* **Output Classifications**:
  * **Safe (Score 0 - 35)**: Proceeding normally on path.
  * **Suspicious (Score 36 - 70)**: Route deviation detected, unusual stops, or late-night walk in high-crime density index.
  * **Dangerous (Score 71 - 100)**: Route deviation + prolonged stop + no user feedback, or direct collision impact.

### 3.2 Audio Distress Classification Pipeline
Identifies emergency events using micro-sound snippets.

```mermaid
graph LR
    Mic[Microphone Input] -->|PCM Audio stream| Chunk[Audio Chunking 1-2s]
    Chunk -->|Convert| MelSpec[Compute Log-Mel Spectrogram]
    MelSpec -->|Feature Matrix| CNN[Pre-trained Audio CNN / MobileNetV2]
    CNN -->|Class Probabilities| Decision[Threshold Evaluator]
    Decision -->|Aggressive/Scream Confidence > 80%| Alarm[Trigger Verification Alarm]
```

* **On-Device vs. Server Execution**: 
  * The Flutter app records audio in 2-second overlapping segments.
  * A lightweight local CNN (TFLite implementation) checks for generic high-pitch scream profiles.
  * If identified, the raw snippet is securely dispatched to the backend API (`POST /api/v1/evidence/upload/`) for verification by a larger server-side model (PyTorch Audio CNN) and stored as secure evidence.

---

## 4. Mobile Hardware Integrations & Background Processing

For Saathi Shield to offer reliable real-time protection, the mobile application interacts with device hardware components through isolated native channels:

1. **Background Service Lifecycle**:
   * Uses native service structures (`Foreground Service` on Android with a persistent notification, and `Background Fetch/Location` with high accuracy permissions on iOS).
   * Ensures the operating system does not kill the thread during travel mode or active SOS tracking.

2. **Sensors (Accelerometer + Gyroscope)**:
   * Listens to sensor stream updates at a frequency of 50Hz.
   * **Fall Detection Algorithm**: Calculates total acceleration magnitude:
     $$A_m = \sqrt{a_x^2 + a_y^2 + a_z^2}$$
   * A fall is registered if $A_m$ falls below a low-G threshold (free fall, e.g., $< 0.3g$) followed by a high-G spike (impact collision, e.g., $> 3.0g$) and subsequent lack of angular velocity variation (inactivity).

3. **Siren & Flashlight Integration**:
   * Toggles the system torch at 200ms intervals during SOS (strobe light).
   * Sets screen brightness to 100% and triggers full-screen alarms using maximum media volume for the siren output.

4. **Evidence Security**:
   * Video and audio streams are written directly to temporary flash directories using a local AES-256 symmetric key generated per SOS session.
   * Chunks are sequentially uploaded to the server, meaning even if the assailant smashes the physical device, the previously uploaded segments remain safely stored on S3.

---

## 5. Deployment & AWS-Ready Infrastructure

The deployment layout is structured to handle spikes in traffic during public emergencies while ensuring extreme isolation for user safety databases.

### Infrastructure Components

1. **DNS & Edge Network**: AWS Route 53 routes incoming requests. CloudFront distributes static assets (such as tracking portal scripts) and enforces Web Application Firewall (WAF) rule sets to prevent DDoS attacks.
2. **Compute Node (Dockerized Web)**: AWS Elastic Container Service (ECS) running Fargate tasks. Scaling triggers on memory usage or incoming WebSocket connections count.
3. **Database Layer (RDS PostgreSQL)**:
   * Multi-AZ deployment for failover recovery.
   * Point-in-time recovery enabled.
   * PostGIS spatial indexing enabled.
4. **Cache & WebSocket State Management**: AWS ElastiCache for Redis.
5. **Security & Cryptography**:
   * AWS Key Management Service (KMS) for envelope encryption of media files.
   * All API traffic enforces SSL/TLS 1.3 protocol requirements.
