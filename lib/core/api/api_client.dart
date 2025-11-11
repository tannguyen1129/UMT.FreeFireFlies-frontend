import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  final Dio dio;
  static const String _baseUrl = 'http://192.168.1.15:3000';

  ApiClient()
      : dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(milliseconds: 5000),
    receiveTimeout: const Duration(milliseconds: 5000),
  )) {
    // 🚀 THÊM INTERCEPTOR ĐỂ ĐÍNH KÈM JWT
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService().getToken(); // Lấy token
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token'; // Thêm header
          }
          return handler.next(options);
        },
      ),
    );
  }
}