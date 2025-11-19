import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(BaseOptions(
    // Bỏ 'static', đọc trực tiếp từ dotenv khi khởi tạo class
    baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000',
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  )) {

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await SecureStorageService().getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            // Xử lý lỗi nếu việc lấy token thất bại (tùy chọn)
            print('Error getting token: $e');
          }
          return handler.next(options);
        },
      ),
    );
  }
}