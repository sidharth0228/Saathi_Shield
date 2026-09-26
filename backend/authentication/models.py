import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    ROLE_CHOICES = (
        ('USER', 'User'),
        ('ADMIN', 'Admin'),
        ('RESPONDER', 'Responder'),
    )
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True, null=True, blank=True)
    phone = models.CharField(max_length=20, unique=True, null=True, blank=True)
    google_id = models.CharField(max_length=255, unique=True, null=True, blank=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='USER')
    is_verified = models.BooleanField(default=False)
    profile_photo = models.URLField(max_length=512, null=True, blank=True)
    otp_secret = models.CharField(max_length=32, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Allow log in with email as USERNAME_FIELD
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username', 'first_name', 'last_name']

    def save(self, *args, **kwargs):
        if not self.username:
            self.username = self.email or self.phone or str(self.id)
        if not self.email and self.phone:
            # Fallback mock email for unique index integrity
            self.email = f"{self.phone}@saathishield.local"
        super().save(*args, **kwargs)

    def __str__(self):
        return self.email or self.phone or str(self.id)


class MedicalProfile(models.Model):
    BLOOD_GROUPS = (
        ('A+', 'A+'),
        ('A-', 'A-'),
        ('B+', 'B+'),
        ('B-', 'B-'),
        ('AB+', 'AB+'),
        ('AB-', 'AB-'),
        ('O+', 'O+'),
        ('O-', 'O-'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='medical_profile')
    blood_group = models.CharField(max_length=5, choices=BLOOD_GROUPS, null=True, blank=True)
    allergies = models.TextField(null=True, blank=True)
    medical_conditions = models.TextField(null=True, blank=True)
    medications = models.TextField(null=True, blank=True)
    organ_donor = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Medical Profile of {self.user}"


class EmergencyContact(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='contacts')
    name = models.CharField(max_length=150)
    relationship = models.CharField(max_length=50)
    phone = models.CharField(max_length=20)
    email = models.EmailField(null=True, blank=True)
    notify_sms = models.BooleanField(default=True)
    notify_email = models.BooleanField(default=True)
    notify_push = models.BooleanField(default=True)
    priority = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['priority', 'created_at']

    def __str__(self):
        return f"{self.name} ({self.relationship}) for {self.user}"
