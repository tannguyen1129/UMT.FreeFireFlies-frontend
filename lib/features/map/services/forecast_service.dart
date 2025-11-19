import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart'; // Import ApiClient

class ForecastService {
  final ApiClient _apiClient = ApiClient();

  // Hàm gọi API lấy dữ liệu dự báo
  Future<List<dynamic>> getAqiForecasts() async {
    try {
      // APIClient đã tự động đính kèm JWT
      final response = await _apiClient.dio.get(
        '/aqi/forecasts', // 👈 Gọi API Gateway
      );

      if (response.statusCode == 200) {
        // Trả về một mảng các thực thể AirQualityForecast
        return response.data as List<dynamic>;
      } else {
        throw Exception('Không thể tải dữ liệu dự báo');
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