/*
 * Copyright 2025 Green-AQI Navigator Team
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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