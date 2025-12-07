import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io'; // 👈 Import để check Platform
import '../storage/secure_storage_service.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_BASE_URL'] ??
        (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000'),
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  )) {

    // Thêm Interceptor để tự động gắn Token
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            // Lấy token từ bộ nhớ an toàn
            final token = await SecureStorageService().getToken();

            print("🔑 Token gửi đi: ${token != null ? 'Có (${token.substring(0, 5)}...)' : 'KHÔNG CÓ'}");

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            print('⚠️ Lỗi lấy token: $e');
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          print("❌ API Error: [${e.response?.statusCode}] ${e.requestOptions.path}");
          return handler.next(e);
        },
      ),
    );
  }
}