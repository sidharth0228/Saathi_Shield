# Saathi Shield - Database Schema Design

This document details the PostgreSQL relational database schema for **Saathi Shield**, incorporating geospatial extensions (PostGIS) and optimized index strategies.

---

## 1. Entity Relationship & Schema Summary

```mermaid
erDiagram
    User ||--o1 MedicalProfile : "has"
    User ||--o{ EmergencyContact : "defines"
    User ||--o{ TravelSession : "creates"
    User ||--o{ Alert : "triggers"
    User ||--o1 ResponderProfile : "registers"
    User ||--o{ Notification : "receives"
    
    TravelSession ||--o{ Alert : "associated with"
    TravelSession ||--o{ ThreatAssessment : "assessed by"
    
    Alert ||--o{ EvidenceFile : "contains"
    Alert ||--o{ AlertResponse : "dispatched to"
    
    User ||--o{ AlertResponse : "responds as"
```

---

## 2. Table Specifications & Schema Details

### 2.1 custom_user (`users_user`)
Extends Django's `AbstractUser` to use email/phone as identifiers with role assignments.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Unique user identifier |
| `email` | VARCHAR(255) | UNIQUE, NULL | Email address |
| `phone` | VARCHAR(20) | UNIQUE, NULL | Mobile number (E.164 format) |
| `password` | VARCHAR(128) | NOT NULL | Hashed password |
| `first_name` | VARCHAR(150) | NOT NULL | User's first name |
| `last_name` | VARCHAR(150) | NOT NULL | User's last name |
| `google_id` | VARCHAR(255) | UNIQUE, NULL | Auth ID for Google Sign-In |
| `role` | VARCHAR(20) | NOT NULL, Default: `'USER'` | Choices: `'USER'`, `'ADMIN'`, `'RESPONDER'` |
| `is_verified` | BOOLEAN | NOT NULL, Default: `FALSE` | Phone/Email verification check |
| `is_active` | BOOLEAN | NOT NULL, Default: `TRUE` | Soft-deletion toggle |
| `is_staff` | BOOLEAN | NOT NULL, Default: `FALSE` | Django admin panel access check |
| `profile_photo` | VARCHAR(512) | NULL | URL to photo in S3 bucket |
| `created_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Last updated timestamp |

* **Indexes**:
  * `idx_users_email`: B-Tree on `email` (for login lookups)
  * `idx_users_phone`: B-Tree on `phone` (for OTP lookup)

---

### 2.2 medical_profile (`users_medicalprofile`)
Stores medical history details shared during active medical emergencies.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Unique profile identifier |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE, UNIQUE | Link to user |
| `blood_group` | VARCHAR(5) | NULL | Choices: `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-` |
| `allergies` | TEXT | NULL | Known drug or environmental allergies |
| `medical_conditions` | TEXT | NULL | E.g. Hypertension, Diabetes, Epilepsy |
| `medications` | TEXT | NULL | Current prescribed medications |
| `organ_donor` | BOOLEAN | NOT NULL, Default: `FALSE` | Organ donor check status |
| `created_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Timestamp created |
| `updated_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Timestamp updated |

---

### 2.3 emergency_contact (`users_emergencycontact`)
Trusted individuals contacted during emergency escalations.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Unique contact identifier |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE | Associated user |
| `name` | VARCHAR(150) | NOT NULL | Contact name |
| `relationship` | VARCHAR(50) | NOT NULL | Relationship (e.g., Parent, Spouse, Friend) |
| `phone` | VARCHAR(20) | NOT NULL | Mobile number (E.164 format) |
| `email` | VARCHAR(255) | NULL | Optional email |
| `notify_sms` | BOOLEAN | NOT NULL, Default: `TRUE` | Enable/Disable SMS escalations |
| `notify_email` | BOOLEAN | NOT NULL, Default: `TRUE` | Enable/Disable Email notifications |
| `notify_push` | BOOLEAN | NOT NULL, Default: `TRUE` | Enable/Disable FCM triggers |
| `priority` | INTEGER | NOT NULL, Default: `1` | Alert dispatch ordering priority (1, 2, 3...) |
| `created_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Timestamp created |
| `updated_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Timestamp updated |

* **Indexes**:
  * `idx_contacts_user_priority`: Composite B-Tree on `(user_id, priority)`

---

### 2.4 travel_session (`travel_travelsession`)
Tracks real-time journeys when a user is in Safe Travel Mode.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Travel session ID |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE | Traveler profile |
| `source_address` | VARCHAR(255) | NOT NULL | Start address label |
| `source_lat` | DECIMAL(9, 6) | NOT NULL | Source latitude coordinate |
| `source_lng` | DECIMAL(9, 6) | NOT NULL | Source longitude coordinate |
| `dest_address` | VARCHAR(255) | NOT NULL | Destination address label |
| `dest_lat` | DECIMAL(9, 6) | NOT NULL | Destination latitude coordinate |
| `dest_lng` | DECIMAL(9, 6) | NOT NULL | Destination longitude coordinate |
| `current_lat` | DECIMAL(9, 6) | NULL | Last reported latitude coordinate |
| `current_lng` | DECIMAL(9, 6) | NULL | Last reported longitude coordinate |
| `route_geojson` | JSONB | NOT NULL | Geometry points of route from OpenRouteService |
| `status` | VARCHAR(20) | NOT NULL | Choices: `PLANNED`, `ACTIVE`, `DEVIATED`, `SOS_TRIGGERED`, `COMPLETED`, `CANCELLED` |
| `risk_level` | VARCHAR(10) | NOT NULL, Default: `'LOW'` | Choices: `LOW`, `MEDIUM`, `HIGH` |
| `start_time` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Started timestamp |
| `expected_duration_minutes` | INTEGER | NOT NULL | Route duration estimate |
| `actual_end_time` | TIMESTAMPTZ | NULL | Timestamp of completion |
| `created_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Log insertion time |

* **Indexes**:
  * `idx_travel_user_status`: Composite B-Tree on `(user_id, status)`
  * `idx_travel_active_coordinates`: GIST on points `(current_lat, current_lng)` (if using geometry types)

---

### 2.5 alert (`alerts_alert`)
Created during SOS triggers. Holds tracking tokens and system metadata.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Alert case ID |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE | SOS triggerer |
| `travel_session_id` | UUID | FOREIGN KEY (travel_session.id) ON DELETE SET NULL, NULL | Optional associated journey |
| `latitude` | DECIMAL(9, 6) | NOT NULL | Emergency start latitude |
| `longitude` | DECIMAL(9, 6) | NOT NULL | Emergency start longitude |
| `trigger_type` | VARCHAR(20) | NOT NULL | Choices: `ONE_TAP_SOS`, `VOICE_COMMAND`, `FALL_DETECTED`, `ROUTE_DEVIATION`, `AUDIO_DISTRESS`, `MEDICAL_EMERGENCY` |
| `battery_percentage` | INTEGER | NULL | Phone battery percentage during event |
| `network_status` | VARCHAR(20) | NOT NULL, Default: `'GOOD'` | Choices: `EXCELLENT`, `GOOD`, `POOR`, `OFFLINE` |
| `status` | VARCHAR(20) | NOT NULL, Default: `'ACTIVE'` | Choices: `ACTIVE`, `RESOLVED`, `FALSE_ALARM` |
| `secure_token` | VARCHAR(64) | UNIQUE, NOT NULL | Cryptographic tracking token for shared link |
| `created_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Incident start timestamp |
| `resolved_at` | TIMESTAMPTZ | NULL | Resolution timestamp |
| `resolved_by_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE SET NULL, NULL | Operator/User who closed the case |

* **Indexes**:
  * `idx_alerts_secure_token`: Hash index on `secure_token`
  * `idx_alerts_status`: B-Tree on `status` (for active tracking board query)

---

### 2.6 responder_profile (`community_responderprofile`)
Dynamic location cache and opt-in settings for volunteer community responders.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Responder ID |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE, UNIQUE | Associated user account |
| `location` | GEOMETRY(Point, 4326) | NULL | PostGIS spatial point for mapping query |
| `latitude` | DECIMAL(9, 6) | NOT NULL | Numeric latitude for API payload |
| `longitude` | DECIMAL(9, 6) | NOT NULL | Numeric longitude for API payload |
| `is_available` | BOOLEAN | NOT NULL, Default: `TRUE` | Duty status toggle |
| `privacy_share_location` | BOOLEAN | NOT NULL, Default: `TRUE` | Anonymize active location tracking check |
| `last_active_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Dynamic location update heartbeat |

* **Indexes**:
  * `idx_responder_spatial_loc`: GIST Spatial Index on `location` (allows 100ms lookup of closest responders within dynamic boundary)

---

### 2.7 alert_response (`community_alertresponse`)
Tracks status dispatch workflow for community responders and emergency services.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Dispatch transaction ID |
| `alert_id` | UUID | FOREIGN KEY (alerts_alert.id) ON DELETE CASCADE | SOS incident link |
| `responder_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE | Associated responder user |
| `status` | VARCHAR(20) | NOT NULL | Choices: `DISPATCHED`, `ACCEPTED`, `EN_ROUTE`, `ARRIVED`, `COMPLETED`, `CANCELLED` |
| `responder_lat` | DECIMAL(9, 6) | NULL | Last pinged latitude of responder |
| `responder_lng` | DECIMAL(9, 6) | NULL | Last pinged longitude of responder |
| `accepted_at` | TIMESTAMPTZ | NULL | Accepted offer timestamp |
| `arrived_at` | TIMESTAMPTZ | NULL | On-scene arrival timestamp |
| `completed_at` | TIMESTAMPTZ | NULL | Case resolved timestamp |
| `cancelled_at` | TIMESTAMPTZ | NULL | Cancellation timestamp |

* **Indexes**:
  * `idx_response_alert_status`: Composite B-Tree on `(alert_id, status)`

---

### 2.8 evidence_file (`alerts_evidencefile`)
Metadata for encrypted recordings uploaded during active SOS.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Evidence record ID |
| `alert_id` | UUID | FOREIGN KEY (alerts_alert.id) ON DELETE CASCADE | Emergency incident link |
| `file_url` | VARCHAR(512) | NOT NULL | S3 storage URL link |
| `file_type` | VARCHAR(20) | NOT NULL | Choices: `AUDIO`, `VIDEO_FRONT`, `VIDEO_BACK`, `IMAGE` |
| `encryption_iv` | VARCHAR(64) | NOT NULL | Initialization vector used to encrypt file |
| `file_size_bytes` | BIGINT | NOT NULL | Size in bytes |
| `duration_seconds` | INTEGER | NULL | Duration of audio/video segment |
| `uploaded_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Upload date |

---

### 2.9 threat_assessment (`ai_threatassessment`)
AI scoring assessment metrics history.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Assessment ID |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE | Inspected user |
| `travel_session_id` | UUID | FOREIGN KEY (travel_session.id) ON DELETE SET NULL, NULL | Link to travel log |
| `alert_id` | UUID | FOREIGN KEY (alerts_alert.id) ON DELETE SET NULL, NULL | Link to SOS instance |
| `latitude` | DECIMAL(9, 6) | NOT NULL | Tested location latitude |
| `longitude` | DECIMAL(9, 6) | NOT NULL | Tested location longitude |
| `risk_score` | DECIMAL(5, 2) | NOT NULL | Calculated Hazard Rating (0.00 to 100.00) |
| `risk_label` | VARCHAR(15) | NOT NULL | Choices: `SAFE`, `SUSPICIOUS`, `DANGEROUS` |
| `factors_json` | JSONB | NOT NULL | Key-value factors context (deviation_pct, crime_rate, etc.) |
| `assessed_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Evaluation timestamp |

* **Indexes**:
  * `idx_threat_user_date`: Composite B-Tree on `(user_id, assessed_at DESC)`

---

### 2.10 notification (`notifications_notification`)
Delivery logs for mobile pushes and app notifications.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Notification record ID |
| `user_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE CASCADE | Message recipient |
| `title` | VARCHAR(255) | NOT NULL | Title text |
| `message` | TEXT | NOT NULL | Content payload message body |
| `notification_type` | VARCHAR(20) | NOT NULL | Choices: `SOS_ALERT`, `TRAVEL_UPDATE`, `DISASTER_ALERT`, `SYSTEM_INFO` |
| `is_read` | BOOLEAN | NOT NULL, Default: `FALSE` | Read status |
| `sent_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Dispatch timestamp |

---

### 2.11 disaster_alert (`notifications_disasteralert`)
Area-based alerts broadcasted to all users in a specific polygon.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY, Default: `uuid_generate_v4()` | Disaster event ID |
| `title` | VARCHAR(255) | NOT NULL | Hazard name |
| `message` | TEXT | NOT NULL | Response instruction description |
| `event_type` | VARCHAR(20) | NOT NULL | Choices: `FLOOD`, `CYCLONE`, `EARTHQUAKE`, `FIRE`, `PUBLIC_EMERGENCY` |
| `severity` | VARCHAR(15) | NOT NULL | Choices: `INFO`, `WARNING`, `CRITICAL` |
| `location_center` | GEOMETRY(Point, 4326) | NULL | PostGIS epicenter location |
| `location_center_lat` | DECIMAL(9, 6) | NOT NULL | Numeric latitude representation |
| `location_center_lng` | DECIMAL(9, 6) | NOT NULL | Numeric longitude representation |
| `radius_meters` | INTEGER | NOT NULL | Buffer distance affected radius |
| `created_at` | TIMESTAMPTZ | NOT NULL, Default: `NOW()` | Announcement creation |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Expiry time |
| `created_by_id` | UUID | FOREIGN KEY (users_user.id) ON DELETE SET NULL, NULL | Operator/Admin account who initialized |

* **Indexes**:
  * `idx_disaster_spatial_loc`: GIST Spatial Index on `location_center`
  * `idx_disaster_expiry`: B-Tree on `expires_at` (allows filtering out stale records quickly)
