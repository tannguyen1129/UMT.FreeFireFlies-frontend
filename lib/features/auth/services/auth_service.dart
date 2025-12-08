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
import '../../../core/storage/secure_storage_service.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final SecureStorageService _storageService = SecureStorageService();

  // --- Hàm Đăng Nhập ---
  Future<String> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final String token = response.data['access_token'];

        await _storageService.saveToken(token);
        return token;
      } else {
        throw Exception('Đăng nhập thất bại');
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['message'] ?? 'Lỗi mạng';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Đã xảy ra lỗi không xác định: $e');
    }
  }

  // --- Hàm Đăng Ký ---
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone_number': phone,
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Đăng ký thất bại.');
      }
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? 'Lỗi kết nối';
      throw Exception(msg);
    }
  }

  Future<void> logout() async {
    try {
      // 1. Xóa token khỏi thiết bị (Quan trọng nhất)
      await _storageService.deleteToken();

      // 2. (Tùy chọn) Gọi API Backend nếu cần
      // await _apiClient.dio.post('/auth/logout');

      print('Đã đăng xuất thành công (Token xóa khỏi storage)');
    } catch (e) {
      print('Lỗi khi đăng xuất: $e');
      // Vẫn phải xóa token dù có lỗi gì đi nữa để người dùng không bị kẹt
      await _storageService.deleteToken();
    }
  }
}