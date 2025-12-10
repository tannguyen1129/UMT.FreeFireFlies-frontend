import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../storage/secure_storage_service.dart';

import '../../../navigator_key.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';


class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  late final Dio _dio;
  final SecureStorageService _secureStorage = SecureStorageService();
  bool _isHandlingAuthError = false;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        onResponse: (response, handler) {
          _isHandlingAuthError = false; // Reset cờ khi mạng ổn
          return handler.next(response);
        },

        onError: (DioException e, handler) {
          final statusCode = e.response?.statusCode;

          // 🛑 CHỈ LOGOUT KHI 401 (Token hết hạn/sai)
          // 403 (Forbidden) nghĩa là user login rồi nhưng không có quyền xem -> Kệ nó.
          if (statusCode == 401) {

            if (_isHandlingAuthError) {
              return handler.next(e);
            }

            _isHandlingAuthError = true;
            print("🚨 API Client: Token hết hạn (401). Đang đăng xuất...");

            final context = navigatorKey.currentContext;
            if (context != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

                if (authProvider.isAuthenticated) {
                  authProvider.logout();

                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại."),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              });
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // --- Wrapper Methods ---
  Future<Response> get(String path, {Map<String, dynamic>? params}) async => await _dio.get(path, queryParameters: params);
  Future<Response> post(String path, {dynamic data}) async => await _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) async => await _dio.put(path, data: data);
  Future<Response> patch(String path, {dynamic data}) async => await _dio.patch(path, data: data);
  Future<Response> delete(String path) async => await _dio.delete(path);

  Dio get dio => _dio;
}