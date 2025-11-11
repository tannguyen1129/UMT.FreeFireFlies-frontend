import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class UserDataService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      // Gọi đến API được bảo vệ (Gateway sẽ proxy đến cổng 3001)
      final response = await _apiClient.dio.get('/users/me');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch user profile');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
      throw Exception('Lỗi mạng hoặc server: ${e.message}');
    }
  }
}