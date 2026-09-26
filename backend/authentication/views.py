from rest_framework import status, viewsets, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404

from .models import MedicalProfile, EmergencyContact
from .serializers import (
    UserSerializer, RegisterSerializer, MedicalProfileSerializer,
    EmergencyContactSerializer, OTPSendSerializer, OTPVerifySerializer, GoogleLoginSerializer
)
from .services import generate_otp, verify_otp_code, send_sms_notification, verify_google_id_token

User = get_user_model()

def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Dispatch OTP automatically if phone was provided
        if user.phone:
            otp = generate_otp(user.phone)
            send_sms_notification(user.phone, f"Saathi Shield: Your OTP code is {otp}. Valid for 5 minutes.")

        return Response({
            "message": "User registered successfully. Verification OTP dispatched.",
            "user": UserSerializer(user).data
        }, status=status.HTTP_201_CREATED)


class OTPSendView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPSendSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data['phone']

        # Ensure user exists, otherwise auto-create account for seamless onboarding
        user, created = User.objects.get_or_create(
            phone=phone,
            defaults={
                'username': phone,
                'is_verified': False
            }
        )
        if created:
            MedicalProfile.objects.create(user=user)

        otp = generate_otp(phone)
        send_sms_notification(phone, f"Saathi Shield: Your OTP login code is {otp}. Valid for 5 minutes.")
        
        return Response({
            "message": "OTP dispatch request processed successfully.",
            "is_new_user": created
        }, status=status.HTTP_200_OK)


class OTPVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data['phone']
        otp_code = serializer.validated_data['otp_code']

        # Verify
        if not verify_otp_code(phone, otp_code):
            return Response({"error": "Invalid or expired OTP code."}, status=status.HTTP_400_BAD_REQUEST)

        # Log user in
        user = get_object_or_404(User, phone=phone)
        user.is_verified = True
        user.save()

        tokens = get_tokens_for_user(user)
        return Response({
            **tokens,
            "user": UserSerializer(user).data
        }, status=status.HTTP_200_OK)


class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        id_token_str = serializer.validated_data['id_token']

        google_user_info = verify_google_id_token(id_token_str)
        if not google_user_info:
            return Response({"error": "Google token authentication failed."}, status=status.HTTP_400_BAD_REQUEST)

        email = google_user_info.get('email')
        google_id = google_user_info.get('google_id')

        # Retrieve or create user record
        user = User.objects.filter(google_id=google_id).first()
        if not user and email:
            user = User.objects.filter(email=email).first()

        if not user:
            # Create new user record
            user = User.objects.create(
                email=email,
                username=email,
                google_id=google_id,
                first_name=google_user_info.get('first_name', ''),
                last_name=google_user_info.get('last_name', ''),
                profile_photo=google_user_info.get('picture', ''),
                is_verified=True
            )
            MedicalProfile.objects.create(user=user)
        else:
            # Update existing user google fields if missing
            if not user.google_id:
                user.google_id = google_id
            if google_user_info.get('picture') and not user.profile_photo:
                user.profile_photo = google_user_info.get('picture')
            user.is_verified = True
            user.save()

        tokens = get_tokens_for_user(user)
        return Response({
            **tokens,
            "user": UserSerializer(user).data
        }, status=status.HTTP_200_OK)


class MedicalProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile, created = MedicalProfile.objects.get_or_create(user=request.user)
        serializer = MedicalProfileSerializer(profile)
        return Response(serializer.data)

    def put(self, request):
        profile, created = MedicalProfile.objects.get_or_create(user=request.user)
        serializer = MedicalProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class EmergencyContactViewSet(viewsets.ModelViewSet):
    serializer_class = EmergencyContactSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmergencyContact.objects.filter(user=self.request.user)
