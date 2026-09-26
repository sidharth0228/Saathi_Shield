import pytest
from django.urls import reverse
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.utils import timezone

from authentication.models import MedicalProfile, EmergencyContact
from alerts.models import Alert, AlertLocationHistory
from travel.models import TravelSession
from community.models import ResponderProfile, AlertResponse
from notifications.models import DisasterAlert

User = get_user_model()

@pytest.mark.django_db
def test_user_onboarding_and_auth_workflow(api_client):
    # 1. Register Account
    url_reg = reverse('register')
    payload = {
        "email": "newuser@example.com",
        "phone": "+19999999999",
        "password": "SecurePassword123!",
        "first_name": "Sidharth",
        "last_name": "Sharma"
    }
    response_reg = api_client.post(url_reg, payload, format='json')
    assert response_reg.status_code == 201
    
    # 2. Check generated OTP code from cache
    phone = payload['phone']
    cached_otp = cache.get(f"otp_code:{phone}")
    assert cached_otp is not None
    assert len(cached_otp) == 6

    # 3. Verify OTP code and retrieve JWT tokens
    url_verify = reverse('otp-verify')
    response_verify = api_client.post(url_verify, {
        "phone": phone,
        "otp_code": cached_otp
    }, format='json')
    assert response_verify.status_code == 200
    assert 'access' in response_verify.data
    assert 'refresh' in response_verify.data
    assert response_verify.data['user']['is_verified'] is True


@pytest.mark.django_db
def test_medical_profile_and_contacts_crud(auth_client, test_user):
    # 1. Read / Update Medical Profile
    url_med = reverse('medical-profile')
    response_get = auth_client.get(url_med)
    assert response_get.status_code == 200

    response_put = auth_client.put(url_med, {
        "blood_group": "AB-",
        "allergies": "Gluten",
        "medical_conditions": "Mild Asthma"
    }, format='json')
    assert response_put.status_code == 200
    assert response_put.data['blood_group'] == 'AB-'

    # 2. Create Emergency Contact
    url_contact = reverse('emergency-contacts-list')
    response_contact = auth_client.post(url_contact, {
        "name": "Jane Doe",
        "relationship": "Spouse",
        "phone": "+1987654321",
        "notify_sms": True,
        "priority": 1
    }, format='json')
    assert response_contact.status_code == 201
    assert response_contact.data['name'] == 'Jane Doe'


@pytest.mark.django_db
def test_sos_incident_trigger_and_resolution(auth_client, test_user):
    # 1. Trigger SOS Alert
    url_trigger = reverse('alert-trigger')
    payload = {
        "latitude": "28.613900",
        "longitude": "77.209000",
        "trigger_type": "ONE_TAP_SOS",
        "battery_percentage": 85,
        "network_status": "GOOD"
    }
    response_trigger = auth_client.post(url_trigger, payload, format='json')
    assert response_trigger.status_code == 201
    assert 'alert_id' in response_trigger.data
    assert 'secure_token' in response_trigger.data

    alert_id = response_trigger.data['alert_id']
    secure_token = response_trigger.data['secure_token']

    # 2. Fetch public tracking link endpoint
    url_track = reverse('public-track', kwargs={'secure_token': secure_token})
    response_track = auth_client.get(url_track)
    assert response_track.status_code == 200
    assert response_track.data['status'] == 'ACTIVE'

    # 3. Resolve Emergency Alert
    url_resolve = reverse('alert-resolve')
    response_resolve = auth_client.post(url_resolve, {
        "alert_id": alert_id,
        "is_false_alarm": True
    }, format='json')
    assert response_resolve.status_code == 200

    # Verification checks
    alert = Alert.objects.get(id=alert_id)
    assert alert.status == 'FALSE_ALARM'
    assert alert.resolved_at is not None


@pytest.mark.django_db
def test_travel_mode_route_deviation_escalation(auth_client, test_user):
    # 1. Start Travel Session
    url_start = reverse('travel-start')
    payload = {
        "source_address": "Connaught Place",
        "source_lat": "28.630400",
        "source_lng": "77.217700",
        "dest_address": "Airport",
        "dest_lat": "28.556200",
        "dest_lng": "77.100000",
        "expected_duration_minutes": 30
    }
    response_start = auth_client.post(url_start, payload, format='json')
    assert response_start.status_code == 201
    session_id = response_start.data['id']

    # 2. Ping 1: Close to planned path (no deviation)
    url_ping = reverse('travel-ping')
    response_ping1 = auth_client.post(url_ping, {
        "session_id": session_id,
        "current_lat": "28.630400",
        "current_lng": "77.217700"
    }, format='json')
    assert response_ping1.status_code == 200
    assert response_ping1.data['route_deviation_detected'] is False

    # 3. Ping 2, 3, 4: Far from path (consecutive deviations triggering auto SOS)
    # Target path goes straight between 28.6304,77.2177 and 28.5562,77.1000.
    # Deviation coordinate is placed way out (e.g. 29.9, 78.5)
    for _ in range(3):
        response_ping_dev = auth_client.post(url_ping, {
            "session_id": session_id,
            "current_lat": "29.900000",
            "current_lng": "78.500000"
        }, format='json')
        assert response_ping_dev.status_code == 200

    # Validate that TravelSession status escalated to SOS_TRIGGERED
    session = TravelSession.objects.get(id=session_id)
    assert session.status == 'SOS_TRIGGERED'
    
    # Validate that active SOS Alert was automatically created
    assert Alert.objects.filter(travel_session=session, status='ACTIVE').exists()


@pytest.mark.django_db
def test_community_responder_matching_and_dispatch(auth_client, test_user, api_client):
    # 1. Setup responder user
    responder_user = User.objects.create_user(
        email="responder@saathishield.local",
        username="responder_user",
        password="Password123!",
        is_verified=True,
        role='RESPONDER'
    )
    
    # 2. Update responder coordinate location (placed at 28.6140, 77.2080)
    api_client.force_authenticate(user=responder_user)
    url_loc = reverse('responder-location')
    response_loc = api_client.post(url_loc, {
        "latitude": "28.614000",
        "longitude": "77.208000",
        "is_available": True
    }, format='json')
    assert response_loc.status_code == 200

    # 3. Victim triggers active SOS Alert (placed at 28.6139, 77.2090 - ~110m away)
    url_trigger = reverse('alert-trigger')
    response_trigger = auth_client.post(url_trigger, {
        "latitude": "28.613900",
        "longitude": "77.209000",
        "trigger_type": "ONE_TAP_SOS"
    }, format='json')
    alert_id = response_trigger.data['alert_id']

    # 4. Responder fetches nearby alerts
    url_nearby = f"{reverse('nearby-alerts')}?lat=28.614000&lng=77.208000"
    response_nearby = api_client.get(url_nearby)
    assert response_nearby.status_code == 200
    assert len(response_nearby.data) == 1
    assert response_nearby.data[0]['alert_id'] == alert_id

    # 5. Responder accepts assistance dispatch request
    url_accept = reverse('accept-alert', kwargs={'alert_id': alert_id})
    response_accept = api_client.post(url_accept)
    assert response_accept.status_code == 200
    assert AlertResponse.objects.filter(alert_id=alert_id, responder=responder_user, status='ACCEPTED').exists()


@pytest.mark.django_db
def test_regional_disaster_alerts(auth_client, test_user):
    # 1. Create an admin user account
    admin_user = User.objects.create_superuser(
        email="admin@saathishield.local",
        username="admin_user",
        password="Password123!",
        role='ADMIN'
    )

    # 2. Admin publishes a critical warning (epicenter: 28.6139, 77.2090, radius: 5000m)
    auth_client.force_authenticate(user=admin_user)
    url_create = reverse('disaster-create')
    payload = {
        "title": "Severe Cyclone Warning",
        "message": "Immediate evacuation ordered for zone radius.",
        "event_type": "CYCLONE",
        "severity": "CRITICAL",
        "location_center_lat": "28.613900",
        "location_center_lng": "77.209000",
        "radius_meters": 5000,
        "expires_at": timezone.now() + timezone.timedelta(hours=2)
    }
    response_create = auth_client.post(url_create, payload, format='json')
    assert response_create.status_code == 201

    # 3. Test user checks nearby disasters (placed at 28.6140, 77.2092 - ~100m away, inside radius)
    auth_client.force_authenticate(user=test_user)
    url_nearby = f"{reverse('disaster-nearby')}?lat=28.614000&lng=77.209200"
    response_nearby = auth_client.get(url_nearby)
    assert response_nearby.status_code == 200
    assert len(response_nearby.data) == 1
    assert response_nearby.data[0]['title'] == "Severe Cyclone Warning"


@pytest.mark.django_db
def test_route_safety_scoring(auth_client, test_user):
    from ai_engine.models import ThreatAssessment

    # Query Route Safety Score
    url = f"{reverse('safety-score')}?lat=28.614000&lng=77.209200"
    response = auth_client.get(url)
    assert response.status_code == 200
    assert 'safety_score' in response.data
    assert 'risk_label' in response.data
    assert 'factors' in response.data
    assert 'crime_statistics_index' in response.data['factors']
    assert 'illumination_estimate' in response.data['factors']
    assert 'population_density_index' in response.data['factors']

    # Verify a database entry was recorded
    assert ThreatAssessment.objects.filter(user=test_user).exists()
    assessment = ThreatAssessment.objects.filter(user=test_user).first()
    assert float(assessment.latitude) == 28.614000
    assert float(assessment.longitude) == 77.209200


@pytest.mark.django_db
def test_spec_compliant_safety_disasters(auth_client, test_user):
    # 1. Create admin user
    admin_user = User.objects.create_superuser(
        email="admin2@saathishield.local",
        username="admin_user2",
        password="Password123!",
        role='ADMIN'
    )

    # 2. Admin publishes alert
    auth_client.force_authenticate(user=admin_user)
    url_create = reverse('disaster-create')
    payload = {
        "title": "Severe Cyclone Warning 2",
        "message": "Immediate evacuation ordered for zone radius.",
        "event_type": "CYCLONE",
        "severity": "CRITICAL",
        "location_center_lat": "28.613900",
        "location_center_lng": "77.209000",
        "radius_meters": 5000,
        "expires_at": timezone.now() + timezone.timedelta(hours=2)
    }
    response_create = auth_client.post(url_create, payload, format='json')
    assert response_create.status_code == 201

    # 3. Query spec-compliant endpoint
    auth_client.force_authenticate(user=test_user)
    url_safety_disasters = f"{reverse('safety-disasters')}?lat=28.614000&lng=77.209200"
    response = auth_client.get(url_safety_disasters)
    assert response.status_code == 200
    assert len(response.data) > 0
    assert any(alert['title'] == "Severe Cyclone Warning 2" for alert in response.data)


@pytest.mark.django_db
def test_evidence_upload(auth_client, test_user):
    from django.core.files.uploadedfile import SimpleUploadedFile
    from alerts.models import EvidenceFile

    # 1. Trigger SOS Alert to get an alert_id
    url_trigger = reverse('alert-trigger')
    payload = {
        "latitude": "28.613900",
        "longitude": "77.209000",
        "trigger_type": "ONE_TAP_SOS",
        "battery_percentage": 85,
        "network_status": "GOOD"
    }
    response_trigger = auth_client.post(url_trigger, payload, format='json')
    assert response_trigger.status_code == 201
    alert_id = response_trigger.data['alert_id']

    # 2. Mock uploading a small file to /api/v1/evidence/upload/
    dummy_file = SimpleUploadedFile("scream_sample.wav", b"dummy audio contents", content_type="audio/wav")
    url_upload = reverse('evidence-upload-spec')
    upload_payload = {
        "alert_id": alert_id,
        "file_type": "AUDIO",
        "encryption_iv": "1234567890abcdef1234567890abcdef",
        "file": dummy_file
    }
    response_upload = auth_client.post(url_upload, upload_payload, format='multipart')
    assert response_upload.status_code == 202
    assert response_upload.data['status'] == 'UPLOADED'
    assert 'evidence_id' in response_upload.data

    # 3. Check db creation
    assert EvidenceFile.objects.filter(alert_id=alert_id, file_type='AUDIO').exists()

