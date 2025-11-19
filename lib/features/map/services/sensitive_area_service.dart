import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';

class SensitiveAreaService {
  final ApiClient _apiClient = ApiClient();

  // Hàm gọi API tìm khu vực nhạy cảm
  Future<List<dynamic>> findNearbySensitiveAreas(LatLng userLocation, double radius) async {
    try {
      final response = await _apiClient.dio.get(
        '/aqi/sensitive-areas', // 👈 Gọi API mới
        queryParameters: {
          'lat': userLocation.latitude,
          'lng': userLocation.longitude,
          'radius': radius,
        },
      );

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      } else {
        throw Exception('Không thể tải dữ liệu khu vực nhạy cảm');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối');
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }
}