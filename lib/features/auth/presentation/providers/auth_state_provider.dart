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
import '../../services/auth_service.dart'; // Thêm nếu bạn cần gọi lại login/register

class AuthStateProvider with ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  // Constructor
  AuthStateProvider() {
    // Kiểm tra token khi khởi động app
    checkAuthenticationStatus();
  }

  void checkAuthenticationStatus() async {
    final token = await _storageService.getToken();
    _isAuthenticated = token != null;
    notifyListeners();
  }

  void loginSuccess(String token) async {
    await _storageService.saveToken(token);
    _isAuthenticated = true;
    notifyListeners();
  }

  void logout() async {
    await _storageService.deleteToken();
    _isAuthenticated = false;
    notifyListeners();
  }
}