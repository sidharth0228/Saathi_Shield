import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/secure_storage_service.dart';

// 1. Declare State Class Union for Riverpod Auth
abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticated extends AuthState {
  final UserModel user;
  const Authenticated(this.user);
}

class OTPVerificationRequired extends AuthState {
  final String phone;
  const OTPVerificationRequired(this.phone);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// 2. State Services Providers
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final secureStorage = ref.read(secureStorageProvider);
  return ApiService(secureStorage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AuthRepository(apiService);
});

// 3. Main Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final SecureStorageService _secureStorage;
  final LocalStorageService _localStorage;

  AuthNotifier({
    required AuthRepository repository,
    required SecureStorageService secureStorage,
    required LocalStorageService localStorage,
  })  : _repository = repository,
        _secureStorage = secureStorage,
        _localStorage = localStorage,
        super(const AuthInitial()) {
    checkAutoLogin();
  }

  // Auto Login Check
  Future<void> checkAutoLogin() async {
    state = const AuthLoading();
    try {
      final accessToken = await _secureStorage.getAccessToken();
      final cachedUserJson = _localStorage.getCachedUserJson();

      if (accessToken != null && cachedUserJson != null) {
        final Map<String, dynamic> userMap = jsonDecode(cachedUserJson);
        final user = UserModel.fromJson(userMap);
        state = Authenticated(user);
      } else {
        state = const Unauthenticated();
      }
    } catch (e) {
      state = const Unauthenticated();
    }
  }

  // Passwordless Login: Send OTP code
  Future<void> requestLoginOtp(String phone) async {
    state = const AuthLoading();
    try {
      await _repository.sendOtp(phone);
      state = OTPVerificationRequired(phone);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Verify OTP and complete login
  Future<void> verifyOtp(String phone, String otpCode) async {
    state = const AuthLoading();
    try {
      final result = await _repository.verifyOtp(phone: phone, otpCode: otpCode);
      final tokens = result['tokens'];
      final user = result['user'] as UserModel;

      // Save credentials locally
      await _secureStorage.saveAccessToken(tokens.accessToken);
      await _secureStorage.saveRefreshToken(tokens.refreshToken);
      await _localStorage.cacheUserJson(jsonEncode(user.toJson()));

      state = Authenticated(user);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Register account
  Future<void> register({
    required String email,
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    state = const AuthLoading();
    try {
      await _repository.register(
        email: email,
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      state = OTPVerificationRequired(phone);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Google Login OAuth
  Future<void> loginWithGoogle(String idToken) async {
    state = const AuthLoading();
    try {
      final result = await _repository.loginWithGoogle(idToken);
      final tokens = result['tokens'];
      final user = result['user'] as UserModel;

      await _secureStorage.saveAccessToken(tokens.accessToken);
      await _secureStorage.saveRefreshToken(tokens.refreshToken);
      await _localStorage.cacheUserJson(jsonEncode(user.toJson()));

      state = Authenticated(user);
    } catch (e) {
      state = AuthError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Clear state to Unauthenticated on error dismissal
  void resetError() {
    state = const Unauthenticated();
  }

  // Logout workflow
  Future<void> logout() async {
    state = const AuthLoading();
    await _secureStorage.clearAuthData();
    await _localStorage.clearUserCache();
    state = const Unauthenticated();
  }
}

// 4. Global Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.read(authRepositoryProvider);
  final secureStorage = ref.read(secureStorageProvider);
  final localStorage = ref.read(localStorageProvider);
  return AuthNotifier(
    repository: repository,
    secureStorage: secureStorage,
    localStorage: localStorage,
  );
});
