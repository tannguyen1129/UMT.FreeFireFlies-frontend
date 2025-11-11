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