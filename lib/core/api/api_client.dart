import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../navigator_key.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';

    print("🌐 ApiClient đang kết nối tới: $baseUrl");

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
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        onResponse: (response, handler) {
          return handler.next(response);
        },

        onError: (DioException e, handler) {
          final statusCode = e.response?.statusCode;

          // Tự động đăng xuất khi hết phiên (401/403)
          if (statusCode == 401 || statusCode == 403) {
            print("🚨 Lỗi $statusCode: Phiên đăng nhập hết hạn. Đang đăng xuất...");
            final context = navigatorKey.currentContext;

            if (context != null) {
              // Gọi logout mà không cần chờ đợi (fire and forget)
              Provider.of<AuthStateProvider>(context, listen: false).logout();

              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // --- Các hàm tiện ích (Wrapper) ---

  Future<Response> get(String path, {Map<String, dynamic>? params}) async {
    return await _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  // Getter để truy cập Dio gốc nếu cần
  Dio get dio => _dio;
}