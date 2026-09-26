class ApiConstants {
  // Use 10.0.2.2 for Android Emulator connecting to local host, or fallback to localhost
  static const String baseUrl = 'http://localhost:8000/api/v1/';
  
  // Auth endpoints
  static const String register = 'auth/register/';
  static const String otpSend = 'auth/otp/send/';
  static const String otpVerify = 'auth/otp/verify/';
  static const String googleLogin = 'auth/google/';

  // User profile
  static const String medicalProfile = 'user/medical/';
  static const String contacts = 'user/contacts/';

  // SOS endpoints
  static const String sosTrigger = 'sos/trigger/';
  static const String sosResolve = 'sos/resolve/';
  
  // Timeout settings
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;
}
