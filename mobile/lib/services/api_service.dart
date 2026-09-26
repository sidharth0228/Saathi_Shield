import 'dart:async';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import 'secure_storage_service.dart';

class ApiService {
  final Dio dio;
  final SecureStorageService _secureStorage;

  ApiService(this._secureStorage) : dio = Dio() {
    dio.options.baseUrl = ApiConstants.baseUrl;
    
    // Hardened timeouts (5 seconds connection timeout for fast failover/offline queuing)
    dio.options.connectTimeout = const Duration(milliseconds: 5000);
    dio.options.receiveTimeout = const Duration(milliseconds: 5000);
    
    dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          final isAuthEndpoint = path.contains('auth/');
          
          if (!isAuthEndpoint) {
            final token = await _secureStorage.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final refreshToken = await _secureStorage.getRefreshToken();
            
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final refreshResponse = await Dio().post(
                  '${ApiConstants.baseUrl}auth/token/refresh/',
                  data: {'refresh': refreshToken},
                );

                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['access'] as String;
                  await _secureStorage.saveAccessToken(newAccessToken);

                  final options = e.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccessToken';
                  
                  final cloneReq = await dio.request(
                    options.path,
                    options: Options(
                      method: options.method,
                      headers: options.headers,
                    ),
                    data: options.data,
                    queryParameters: options.queryParameters,
                  );
                  return handler.resolve(cloneReq);
                }
              } catch (refreshErr) {
                await _secureStorage.clearAuthData();
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Network retry helper with exponential backoff (for connection timeouts / socket errors)
  Future<Response> _retryRequest(Future<Response> Function() requestFn, {int maxRetries = 3}) async {
    int attempts = 0;
    while (true) {
      try {
        return await requestFn();
      } on DioException catch (e) {
        attempts++;
        final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (attempts >= maxRetries || !isNetworkError) {
          rethrow;
        }
        
        // Wait with exponential backoff (1s, 2s, 4s...)
        await Future.delayed(Duration(seconds: 1 << (attempts - 1)));
      }
    }
  }

  // GET Request helper
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _retryRequest(() => dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      ));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST Request helper
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _retryRequest(() => dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT Request helper
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _retryRequest(() => dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE Request helper
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _retryRequest(() => dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error parser helper
  Exception _handleError(DioException e) {
    String errorMsg = 'An unexpected network error occurred.';
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        errorMsg = data['error'].toString();
      } else if (data is Map && data.containsKey('message')) {
        errorMsg = data['message'].toString();
      } else {
        errorMsg = 'Error code ${e.response?.statusCode}: ${e.response?.statusMessage}';
      }
    } else {
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Connection timed out. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg = 'No internet connection detected.';
      }
    }
    return Exception(errorMsg);
  }
}
