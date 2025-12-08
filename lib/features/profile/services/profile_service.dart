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

  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await _apiClient.dio.get('/users/leaderboard');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      } else {
        throw Exception('Không thể tải bảng xếp hạng');
      }
    } catch (e) {
      return []; // Trả về rỗng nếu lỗi để không crash app
    }
  }

  Future<void> addPoints(int points) async {
    try {
      // Gọi API Backend: POST /users/add-points
      final response = await _apiClient.dio.post(
        '/users/add-points',
        data: {'points': points},
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Không thể cộng điểm');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối');
    }
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