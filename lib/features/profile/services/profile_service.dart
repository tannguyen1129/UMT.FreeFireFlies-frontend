import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart'; // Import ApiClient

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  // Hàm gọi API lấy hồ sơ cá nhân
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      // APIClient đã tự động đính kèm JWT
      final response = await _apiClient.dio.get(
        '/users/me', // 👈 Gọi API Gateway (đã có)
      );

      if (response.statusCode == 200) {
        // Trả về object User (Map)
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Không thể tải hồ sơ người dùng');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn.');
      }
      final errorMsg = e.response?.data['message'] ?? 'Lỗi máy chủ';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }
}