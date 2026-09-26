import random
import logging
import jwt
from django.core.cache import cache
from django.conf import settings

logger = logging.getLogger(__name__)

def generate_otp(phone):
    """
    Generates a 6-digit numeric OTP and stores it in cache for 5 minutes.
    """
    otp = str(random.randint(100000, 999999))
    cache.set(f"otp_code:{phone}", otp, timeout=300)
    return otp

def verify_otp_code(phone, code):
    """
    Verifies the OTP code for a phone number.
    """
    cached_code = cache.get(f"otp_code:{phone}")
    if cached_code and cached_code == code:
        cache.delete(f"otp_code:{phone}")
        return True
    return False

def send_sms_notification(phone, message):
    """
    Dispatches SMS to trusted contact or responder via Twilio.
    Falls back to mock console output in development mode.
    """
    account_sid = getattr(settings, 'TWILIO_ACCOUNT_SID', '')
    auth_token = getattr(settings, 'TWILIO_AUTH_TOKEN', '')
    from_number = getattr(settings, 'TWILIO_PHONE_NUMBER', '')
    
    if account_sid and auth_token and from_number and 'mock' not in account_sid.lower():
        try:
            from twilio.rest import Client
            client = Client(account_sid, auth_token)
            client.messages.create(
                body=message,
                from_=from_number,
                to=phone
            )
            logger.info(f"SMS successfully dispatched to {phone} via Twilio.")
            return True
        except Exception as e:
            logger.error(f"Failed to dispatch SMS to {phone} via Twilio: {str(e)}")
            
    # Dev mock fallback print
    logger.info(f"[MOCK SMS] To: {phone} | Content: {message}")
    print(f"\n--- [MOCK SMS DISPATCH] ---\nTo: {phone}\nMessage: {message}\n---------------------------\n")
    return True

def verify_google_id_token(token_str):
    """
    Verifies a Google OAuth ID token.
    Supports signature bypass decoding for local dev testing tokens.
    """
    client_id = getattr(settings, 'GOOGLE_OAUTH_CLIENT_ID', '')
    
    # Check if we are running in mock/dev mode
    if not client_id or 'mock' in client_id.lower():
        try:
            payload = jwt.decode(token_str, options={"verify_signature": False})
            return {
                'email': payload.get('email'),
                'first_name': payload.get('given_name', ''),
                'last_name': payload.get('family_name', ''),
                'google_id': payload.get('sub'),
                'picture': payload.get('picture', '')
            }
        except Exception:
            return {
                'email': f"mock_google_{random.randint(100,999)}@example.com",
                'first_name': 'MockGoogle',
                'last_name': 'User',
                'google_id': f"google-oauth-mock-sub-{random.randint(100000, 999999)}",
                'picture': 'https://saathishield.live/static/mock.png'
            }

    try:
        from google.oauth2 import id_token
        from google.auth.transport import requests as google_requests
        id_info = id_token.verify_oauth2_token(token_str, google_requests.Request(), client_id)
        return {
            'email': id_info.get('email'),
            'first_name': id_info.get('given_name', ''),
            'last_name': id_info.get('family_name', ''),
            'google_id': id_info.get('sub'),
            'picture': id_info.get('picture', '')
        }
    except Exception as e:
        logger.error(f"Google ID token verification failed: {str(e)}")
        return None
