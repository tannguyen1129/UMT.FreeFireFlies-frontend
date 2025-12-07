import 'package:flutter/material.dart';
import '../../../../core/storage/secure_storage_service.dart';

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
    await _storageService.deleteToken();
    _token = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}