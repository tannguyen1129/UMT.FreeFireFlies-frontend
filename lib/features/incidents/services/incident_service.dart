import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';

class IncidentService {
  final ApiClient _apiClient = ApiClient();

  // 🚀 HÀM MỚI: Lấy danh sách sự cố của TÔI
  Future<List<dynamic>> getMyIncidents() async {
    try {
      // ⚠️ LƯU Ý: API NÀY CHƯA TỒN TẠI Ở BACKEND
      // Chúng ta sẽ phải tạo (GET /aqi/incidents/me) ở bước sau
      final response = await _apiClient.dio.get(
        '/aqi/incidents/me', // 👈 API MỚI CẦN TẠO
      );
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      } else {
        throw Exception('Không thể tải báo cáo của bạn');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ?? 'Lỗi máy chủ';
      throw Exception(errorMsg);
    }
  }

  // 🚀 HÀM MỚI: Lấy danh sách loại sự cố (đã làm ở bước trước)
  Future<List<dynamic>> getIncidentTypes() async {
    try {
      final response = await _apiClient.dio.get(
        '/aqi/incident-types',
      );
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      } else {
        throw Exception('Không thể tải loại sự cố');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ?? 'Lỗi máy chủ';
      throw Exception(errorMsg);
    }
  }

  // Hàm tạo báo cáo (giữ nguyên)
  Future<Map<String, dynamic>> createIncident({
    required LatLng location,
    required int incidentTypeId,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/aqi/incidents',
        data: {
          'incident_type_id': incidentTypeId,
          'description': description,
          'image_url': imageUrl,
          'location': {
            'type': 'Point',
            'coordinates': [location.longitude, location.latitude]
          }
        },
      );
      if (response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Không thể tạo báo cáo');
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