import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getMyProfile() async {
    // ... (Giữ nguyên code cũ)
    try {
      final response = await _apiClient.dio.get('/users/me');
      if (response.statusCode == 200) return response.data as Map<String, dynamic>;
      else throw Exception('Lỗi tải hồ sơ');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi máy chủ');
    } catch (e) { throw Exception('$e'); }
  }

  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? agency,
    String? healthGroup,
  }) async {
    try {
      await _apiClient.dio.put(
        '/users/me',
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'agency_department': agency,
          'health_group': healthGroup,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối');
    }
  }
}