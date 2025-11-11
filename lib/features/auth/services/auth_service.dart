import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  // Hàm đăng nhập
  Future<String> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login', // Đảm bảo gọi qua tiền tố
        data: {
          'email': email,
          'password': password,
        },
        // 🚨 THÊM CONTENT-TYPE RÕ RÀNG 🚨
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final String token = response.data['access_token'];
        return token;
      } else {
        throw Exception('Đăng nhập thất bại');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ?? 'Lỗi mạng';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định');
    }
  }
}