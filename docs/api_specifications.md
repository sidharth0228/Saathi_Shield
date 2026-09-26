# Saathi Shield - API Specifications

This document outlines the REST API and WebSocket interfaces for the **Saathi Shield** safety platform.

---

## 1. Authentication & Security Policy

* **Protocol**: HTTPS / WSS
* **Auth Scheme**: JWT (JSON Web Tokens)
* **Header Format**: `Authorization: Bearer <JWT_ACCESS_TOKEN>`
* **Token Lifespans**:
  * Access Token: 15 Minutes
  * Refresh Token: 7 Days
* **Rate Limits**:
  * Default endpoints: 100 requests / minute / IP
  * SOS endpoints: Uncapped (high-priority bypass)
  * SMS/OTP request: 3 requests / 10 minutes / Phone

---

## 2. REST API Specification

### 2.1 Authentication App (`/api/v1/auth`)

#### 2.1.1 Register Account
* **Endpoint**: `POST /api/v1/auth/register/`
* **Auth Required**: No
* **Request Payload**:
  ```json
  {
    "email": "user@example.com",
    "phone": "+1234567890",
    "password": "StrongPassword123!",
    "first_name": "Sidharth",
    "last_name": "Sharma",
    "role": "USER"
  }
  ```
* **Success Response (201 Created)**:
  ```json
  {
    "message": "User registered successfully. Verification OTP dispatched.",
    "user_id": "c1a2b3c4-d5e6-4f7g-8h9i-0j1k2l3m4n5o"
  }
  ```

#### 2.1.2 Send Phone OTP
* **Endpoint**: `POST /api/v1/auth/otp/send/`
* **Auth Required**: No
* **Request Payload**:
  ```json
  {
    "phone": "+1234567890"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "message": "OTP verification code sent successfully to +1234567890."
  }
  ```

#### 2.1.3 Verify Phone OTP & Login
* **Endpoint**: `POST /api/v1/auth/otp/verify/`
* **Auth Required**: No
* **Request Payload**:
  ```json
  {
    "phone": "+1234567890",
    "otp_code": "582910"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "access": "eyJhbGciOiJIUzI1NiIsIn...",
    "refresh": "eyJhbGciOiJIUzI1NiIsIn...",
    "user": {
      "id": "c1a2b3c4-d5e6-4f7g-8h9i-0j1k2l3m4n5o",
      "email": "user@example.com",
      "phone": "+1234567890",
      "role": "USER"
    }
  }
  ```

#### 2.1.4 Google Login OAuth
* **Endpoint**: `POST /api/v1/auth/google/`
* **Auth Required**: No
* **Request Payload**:
  ```json
  {
    "id_token": "eyJhbGciOiJSUzI1NiIs..."
  }
  ```
* **Success Response (200 OK)**: (Same structure as verification login response containing JWT tokens).

---

### 2.2 Profile & Contacts (`/api/v1/user`)

#### 2.2.1 Get / Update Medical Profile
* **Endpoint**: `GET /api/v1/user/medical/` | `PUT /api/v1/user/medical/`
* **Auth Required**: Yes
* **Request Payload (for PUT)**:
  ```json
  {
    "blood_group": "AB+",
    "allergies": "Penicillin, peanuts",
    "medical_conditions": "Epilepsy, Asthma",
    "medications": "Albuterol inhaler as needed",
    "organ_donor": true
  }
  ```
* **Success Response (200 OK)**: (Returns current profile information block details).

#### 2.2.2 Add Emergency Contact
* **Endpoint**: `POST /api/v1/user/contacts/`
* **Auth Required**: Yes
* **Request Payload**:
  ```json
  {
    "name": "Jane Sharma",
    "relationship": "Spouse",
    "phone": "+1987654321",
    "email": "jane@example.com",
    "notify_sms": true,
    "notify_email": true,
    "notify_push": true,
    "priority": 1
  }
  ```
* **Success Response (210 Created)**:
  ```json
  {
    "id": "01234567-89ab-cdef-0123-456789abcdef",
    "name": "Jane Sharma",
    "relationship": "Spouse",
    "phone": "+1987654321",
    "priority": 1
  }
  ```

---

### 2.3 SOS Alerts (`/api/v1/sos`)

#### 2.3.1 Trigger SOS Emergency
* **Endpoint**: `POST /api/v1/sos/trigger/`
* **Auth Required**: Yes
* **Request Payload**:
  ```json
  {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "trigger_type": "ONE_TAP_SOS",
    "battery_percentage": 87,
    "network_status": "GOOD"
  }
  ```
* **Success Response (201 Created)**:
  ```json
  {
    "alert_id": "f5e4d3c2-b1a0-9e8d-7c6b-5a4f3e2d1c0b",
    "secure_token": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
    "tracking_url": "https://saathishield.live/track/a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
    "message": "Emergency response dispatched. Responders alerted."
  }
  ```

#### 2.3.2 Resolve Active SOS
* **Endpoint**: `POST /api/v1/sos/resolve/`
* **Auth Required**: Yes (Self or Admin)
* **Request Payload**:
  ```json
  {
    "alert_id": "f5e4d3c2-b1a0-9e8d-7c6b-5a4f3e2d1c0b",
    "resolution_pin": "1234",
    "is_false_alarm": false
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "message": "SOS successfully resolved. Security loop closed."
  }
  ```

#### 2.3.3 Track Public Token (No Authentication Required)
* **Endpoint**: `GET /api/v1/sos/track/<secure_token>/`
* **Auth Required**: No
* **Success Response (200 OK)**:
  ```json
  {
    "alert_id": "f5e4d3c2-b1a0-9e8d-7c6b-5a4f3e2d1c0b",
    "user_name": "Sidharth Sharma",
    "phone": "+1234567890",
    "current_lat": 28.6145,
    "current_lng": 77.2105,
    "last_updated": "2026-06-19T01:10:00Z",
    "battery_percentage": 82,
    "medical_profile": {
      "blood_group": "AB+",
      "allergies": "Penicillin",
      "medical_conditions": "Asthma"
    }
  }
  ```

---

### 2.4 Safe Travel Mode (`/api/v1/travel`)

#### 2.4.1 Start Travel Session
* **Endpoint**: `POST /api/v1/travel/start/`
* **Auth Required**: Yes
* **Request Payload**:
  ```json
  {
    "source_address": "Connaught Place, New Delhi",
    "source_lat": 28.6304,
    "source_lng": 77.2177,
    "dest_address": "Indira Gandhi Airport, New Delhi",
    "dest_lat": 28.5562,
    "dest_lng": 77.1000
  }
  ```
* **Success Response (201 Created)**:
  ```json
  {
    "session_id": "aa11bb22-cc33-dd44-ee55-ff66gg77hh88",
    "status": "ACTIVE",
    "expected_duration_minutes": 35,
    "route_geometry": { ... }
  }
  ```

#### 2.4.2 Travel Ping (Heartbeat verification)
* **Endpoint**: `POST /api/v1/travel/ping/`
* **Auth Required**: Yes
* **Request Payload**:
  ```json
  {
    "session_id": "aa11bb22-cc33-dd44-ee55-ff66gg77hh88",
    "current_lat": 28.6189,
    "current_lng": 77.1989,
    "speed_mps": 11.2
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "risk_score": 12.5,
    "risk_label": "SAFE",
    "route_deviation_detected": false
  }
  ```

#### 2.4.3 End Travel Session
* **Endpoint**: `POST /api/v1/travel/end/`
* **Auth Required**: Yes
* **Request Payload**:
  ```json
  {
    "session_id": "aa11bb22-cc33-dd44-ee55-ff66gg77hh88"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "message": "Travel session closed successfully. Thank you for traveling safely."
  }
  ```

---

### 2.5 Community & Responder Network (`/api/v1/community`)

#### 2.5.1 Update Responder Availability / Location
* **Endpoint**: `POST /api/v1/community/responder/location/`
* **Auth Required**: Yes (Role must be `RESPONDER` or `USER` opting in)
* **Request Payload**:
  ```json
  {
    "latitude": 28.6142,
    "longitude": 77.2085,
    "is_available": true
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "message": "Responder status and location coordinates updated."
  }
  ```

#### 2.5.2 Accept Assistance Request
* **Endpoint**: `POST /api/v1/community/alerts/<alert_id>/accept/`
* **Auth Required**: Yes
* **Success Response (200 OK)**:
  ```json
  {
    "response_id": "22ff33ee-44dd-55cc-66bb-77aa88bb99cc",
    "status": "ACCEPTED",
    "victim_details": {
      "name": "Sidharth Sharma",
      "phone": "+1234567890",
      "latitude": 28.6139,
      "longitude": 77.2090
    }
  }
  ```

---

### 2.6 Evidence Security (`/api/v1/evidence`)

#### 2.6.1 Upload Encrypted Evidence Chunks
* **Endpoint**: `POST /api/v1/evidence/upload/`
* **Auth Required**: Yes
* **Request Payload**: Multipart/Form-data
  * `alert_id`: UUID
  * `file_type`: String (`AUDIO` | `VIDEO_FRONT` | `VIDEO_BACK`)
  * `encryption_iv`: String (Hex encoded IV)
  * `file`: Binary file stream blob
* **Success Response (202 Accepted)**:
  ```json
  {
    "evidence_id": "55667788-99aa-bbcc-ddee-ff0011223344",
    "status": "UPLOADED",
    "message": "Evidence chunk stored and queued for AI analysis."
  }
  ```

---

### 2.7 AI Safety & Disaster Warnings (`/api/v1/safety`)

#### 2.7.1 Query Route Safety Score
* **Endpoint**: `GET /api/v1/safety/score/`
* **Auth Required**: Yes
* **Query Params**: `lat`, `lng`
* **Success Response (200 OK)**:
  ```json
  {
    "safety_score": 85,
    "risk_label": "SAFE",
    "factors": {
      "crime_statistics_index": "LOW",
      "illumination_estimate": "HIGH",
      "population_density_index": "MEDIUM"
    }
  }
  ```

#### 2.7.2 Fetch Active Regional Disaster Alerts
* **Endpoint**: `GET /api/v1/safety/disasters/`
* **Auth Required**: Yes
* **Query Params**: `lat`, `lng`
* **Success Response (200 OK)**:
  ```json
  [
    {
      "id": "ddccbbaa-8877-6655-4433-221100ffffff",
      "title": "Severe Flash Flood Warning",
      "message": "Water levels rising quickly near Connaught. Avoid low passes.",
      "severity": "CRITICAL",
      "distance_meters": 450,
      "expires_at": "2026-06-19T06:00:00Z"
    }
  ]
  ```

---

## 3. WebSocket Channel Protocol

WebSocket connections handle sub-second telemetry tracking during emergencies.

### 3.1 Establishing Connection
Clients initiate connections to:
`wss://saathishield.live/ws/sos/<alert_id>/?token=<JWT_ACCESS_TOKEN>`

### 3.2 Client Payload Event: `location_update`
Sent periodically by the victim client app to stream real-time path points:
```json
{
  "event": "location_update",
  "data": {
    "latitude": 28.6148,
    "longitude": 77.2110,
    "battery_percentage": 79,
    "accuracy_meters": 4.5
  }
}
```

### 3.3 Server Broadcast Event: `tracker_telemetry`
Sent by the channel layer to all monitoring contacts and accepted responders:
```json
{
  "event": "tracker_telemetry",
  "data": {
    "alert_id": "f5e4d3c2-b1a0-9e8d-7c6b-5a4f3e2d1c0b",
    "latitude": 28.6148,
    "longitude": 77.2110,
    "battery_percentage": 79,
    "last_updated": "2026-06-19T01:12:30Z",
    "responders": [
      {
        "id": "responder-uuid-1",
        "current_lat": 28.6143,
        "current_lng": 77.2092,
        "status": "EN_ROUTE"
      }
    ]
  }
}
```

### 3.4 Server Event: `assistance_accepted`
Notifies the victim that a community responder has accepted and is en-route:
```json
{
  "event": "assistance_accepted",
  "data": {
    "responder_id": "responder-uuid-1",
    "responder_name": "Vikram Singh",
    "responder_phone": "+1999888777",
    "distance_meters": 320,
    "eta_seconds": 95
  }
}
```
