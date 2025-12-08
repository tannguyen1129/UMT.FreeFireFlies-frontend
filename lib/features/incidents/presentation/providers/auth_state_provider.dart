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

import 'package:flutter/material.dart';
import '../../../../core/storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStateProvider extends ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();

  bool _isAuthenticated = false;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;

  AuthStateProvider() {
    checkLoginStatus();
  }

  // Kiểm tra xem user đã đăng nhập chưa khi mở app
  Future<void> checkLoginStatus() async {
    final savedToken = await _storageService.getToken();
    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      _isAuthenticated = true;
    } else {
      _isAuthenticated = false;
      _token = null;
    }
    notifyListeners(); // Cập nhật UI
  }

  // Hàm gọi khi đăng nhập thành công
  Future<void> login(String newToken) async {
    await _storageService.saveToken(newToken);
    _token = newToken;
    _isAuthenticated = true;
    notifyListeners();
  }

  // Hàm gọi khi đăng xuất
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isAuthenticated = false;

    notifyListeners();
  }
}