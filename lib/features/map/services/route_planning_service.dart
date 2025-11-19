import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart'; // Import ApiClient

class RoutePlanningService {
  final ApiClient _apiClient = ApiClient();

  // Hàm gọi API tìm đường
  Future<Map<String, dynamic>> getRecommendedRoutes(LatLng start, LatLng end) async {
    try {
      // APIClient đã tự động đính kèm JWT
      final response = await _apiClient.dio.get(
        '/aqi/recommendations', // 👈 Gọi API Gateway
        queryParameters: {
          'startLat': start.latitude,
          'startLng': start.longitude,
          'endLat': end.latitude,
          'endLng': end.longitude,
        },
      );

      if (response.statusCode == 200) {
        // Trả về toàn bộ object GeoJSON (FeatureCollection)
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Không thể tải tuyến đường');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn.');
      }
      final errorMsg = e.response?.data['message'] ?? 'Lỗi máy chủ tìm đường';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }
}