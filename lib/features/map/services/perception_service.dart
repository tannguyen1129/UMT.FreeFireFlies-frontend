import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart'; // Import ApiClient

class PerceptionService {
  final ApiClient _apiClient = ApiClient();

  // Hàm gọi API gửi cảm nhận
  Future<void> submitPerception({
    required LatLng location,
    required int feeling, // 1: Tốt, 2: Bình thường, 3: Kém, 4: Ô nhiễm
  }) async {
    try {
      // Gọi API Backend (đã có xác thực JWT tự động trong ApiClient)
      final response = await _apiClient.dio.post(
        '/aqi/perceptions',
        data: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'feeling': feeling,
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Không thể gửi cảm nhận (Status: ${response.statusCode})');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ?? 'Lỗi kết nối máy chủ';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }
}