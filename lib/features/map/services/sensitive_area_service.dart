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