import os
import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from authentication.models import MedicalProfile

# Force Django to run with SQLite in-memory database during testing
os.environ['TESTING'] = 'True'
os.environ['USE_SQLITE'] = 'True'

User = get_user_model()

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def test_user(db):
    user = User.objects.create_user(
        username="testuser",
        email="testuser@example.com",
        phone="+15555555555",
        password="TestPassword123!",
        first_name="Test",
        last_name="User",
        is_verified=True
    )
    # Ensure profile exists
    MedicalProfile.objects.get_or_create(user=user)
    return user

@pytest.fixture
def auth_client(api_client, test_user):
    api_client.force_authenticate(user=test_user)
    return api_client
