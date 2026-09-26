from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import MedicalProfile, EmergencyContact

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'phone', 'first_name', 'last_name', 'role', 'is_verified', 'profile_photo']
        read_only_fields = ['id', 'is_verified', 'role']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['email', 'phone', 'password', 'first_name', 'last_name', 'role']

    def create(self, validated_data):
        import uuid
        role = validated_data.get('role', 'USER')
        email = validated_data.get('email')
        phone = validated_data.get('phone')
        username = email or phone or str(uuid.uuid4())

        user = User.objects.create_user(
            username=username,
            email=email,
            phone=phone,
            password=validated_data.get('password'),
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            role=role,
            is_verified=False
        )
        # Auto-create empty medical profile
        MedicalProfile.objects.create(user=user)
        return user


class MedicalProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalProfile
        fields = ['blood_group', 'allergies', 'medical_conditions', 'medications', 'organ_donor', 'updated_at']


class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'name', 'relationship', 'phone', 'email', 'notify_sms', 'notify_email', 'notify_push', 'priority']
        read_only_fields = ['id']

    def create(self, validated_data):
        user = self.context['request'].user
        return EmergencyContact.objects.create(user=user, **validated_data)


class OTPSendSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    otp_code = serializers.CharField(max_length=10)


class GoogleLoginSerializer(serializers.Serializer):
    id_token = serializers.CharField()
