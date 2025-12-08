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

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';

class IncidentService {
  final ApiClient _apiClient = ApiClient();

  // 1. Lấy danh sách loại sự cố
  Future<List<dynamic>> getIncidentTypes() async {
    try {
      final response = await _apiClient.dio.get('/aqi/incident-types');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      } else {
        throw Exception('Không thể tải loại sự cố');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi kết nối');
    }
  }

  // 2. Upload ảnh (Multipart)
  Future<String> uploadImage(File file) async {
    try {
      String fileName = file.path.split('/').last;

      // Tạo FormData
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      // Gọi API Backend
      final response = await _apiClient.dio.post(
        '/aqi/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data', // Bắt buộc
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Backend trả về: { "url": "http://172.27.../uploads/abc.jpg" }
        return response.data['url'];
      } else {
        throw Exception('Upload ảnh thất bại');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi upload ảnh');
    }
  }

  // 3. Tạo báo cáo sự cố
  Future<void> createIncident({
    required LatLng location,
    required int incidentTypeId,
    String? description,
    String? imageUrl, // URL ảnh đã upload
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/aqi/incidents',
        data: {
          'incident_type_id': incidentTypeId,
          'description': description,
          'image_url': imageUrl,
          'latitude': location.latitude,
          'longitude': location.longitude,
          // Định dạng GeoJSON cho PostGIS
          'location': {
            'type': 'Point',
            'coordinates': [location.longitude, location.latitude]
          }
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Gửi báo cáo thất bại');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Lỗi gửi báo cáo');
    }
  }

  // 4. Lấy báo cáo của tôi
  Future<List<dynamic>> getMyIncidents() async {
    try {
      final response = await _apiClient.dio.get('/aqi/incidents/me');
      return response.data as List<dynamic>;
    } catch (e) {
      throw Exception('Lỗi tải lịch sử báo cáo');
    }
  }

  Future<List<dynamic>> getAllIncidents() async {
    try {
      // Gọi API lấy danh sách sự cố (Public hoặc User đều được)
      final response = await _apiClient.dio.get('/aqi/incidents');

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Lỗi lấy danh sách sự cố: $e');
      return [];
    }
  }

}