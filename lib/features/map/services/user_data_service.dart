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

class UserDataService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      // Gọi đến API được bảo vệ (Gateway sẽ proxy đến cổng 3001)
      final response = await _apiClient.dio.get('/users/me');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch user profile');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
      throw Exception('Lỗi mạng hoặc server: ${e.message}');
    }
  }
}