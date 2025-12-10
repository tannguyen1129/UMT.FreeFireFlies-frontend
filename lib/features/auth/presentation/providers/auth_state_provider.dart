import 'package:flutter/material.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../services/auth_service.dart'; // Import AuthService

class AuthStateProvider extends ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();
  final AuthService _authService = AuthService(); // Khởi tạo AuthService

  bool _isAuthenticated = false;
  bool _isChecking = true; // 🆕 Thêm biến này để hiện màn hình chờ lúc mở app

  bool get isAuthenticated => _isAuthenticated;
  bool get isChecking => _isChecking;

  AuthStateProvider() {
    _checkLoginStatus();
  }

  // 🛡️ HÀM KIỂM TRA QUYỀN LỰC (Logic mới)
  Future<void> _checkLoginStatus() async {
    _isChecking = true;
    notifyListeners();

    try {
      // 1. Lấy token từ máy
      final token = await _storageService.getToken();

      if (token != null && token.isNotEmpty) {
        await _authService.getProfile();

        _isAuthenticated = true; // Token ngon -> Cho vào
        print("✅ Token hợp lệ. Đăng nhập tự động.");
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      // 3. Nếu lỗi (Token thối/Hết hạn/Lỗi mạng) -> Coi như chưa đăng nhập
      print("⚠️ Token không hợp lệ hoặc hết hạn khi khởi động: $e");
      _isAuthenticated = false;
      await _storageService.deleteToken(); // Xóa ngay token rác đi
    } finally {
      _isChecking = false; // Tắt màn hình chờ
      notifyListeners();
    }
  }

  Future<void> loginSuccess() async {
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    notifyListeners();
    await _storageService.deleteToken();
  }
}