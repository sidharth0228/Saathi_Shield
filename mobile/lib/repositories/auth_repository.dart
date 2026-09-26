import '../core/constants/api_constants.dart';
import '../models/auth_tokens.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthRepository {
  final ApiService _apiService;

  AuthRepository(this._apiService);

  // Register a new account
  Future<String> register({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final response = await _apiService.post(
      ApiConstants.register,
      data: {
        'email': email,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'USER', // default role
      },
    );

    if (response.statusCode == 201) {
      return response.data['message'] ?? 'Registration successful. OTP sent.';
    } else {
      throw Exception(response.data['error'] ?? 'Registration failed.');
    }
  }

  // Request/Resend OTP code
  Future<String> sendOtp(String phone) async {
    final response = await _apiService.post(
      ApiConstants.otpSend,
      data: {'phone': phone},
    );

    if (response.statusCode == 200) {
      return response.data['message'] ?? 'OTP code sent successfully.';
    } else {
      throw Exception(response.data['error'] ?? 'Failed to send OTP.');
    }
  }

  // Verify OTP and complete login
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otpCode,
  }) async {
    final response = await _apiService.post(
      ApiConstants.otpVerify,
      data: {
        'phone': phone,
        'otp_code': otpCode,
      },
    );

    if (response.statusCode == 200) {
      final tokens = AuthTokens.fromJson(response.data);
      final user = UserModel.fromJson(response.data['user']);
      return {
        'tokens': tokens,
        'user': user,
      };
    } else {
      throw Exception(response.data['error'] ?? 'OTP verification failed.');
    }
  }

  // Login via Google OAuth idToken
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await _apiService.post(
      ApiConstants.googleLogin,
      data: {'id_token': idToken},
    );

    if (response.statusCode == 200) {
      final tokens = AuthTokens.fromJson(response.data);
      final user = UserModel.fromJson(response.data['user']);
      return {
        'tokens': tokens,
        'user': user,
      };
    } else {
      throw Exception(response.data['error'] ?? 'Google login failed.');
    }
  }
}
