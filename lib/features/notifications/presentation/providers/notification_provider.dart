import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationProvider extends ChangeNotifier {
  // Danh sách lưu trữ thông báo
  final List<RemoteMessage> _messages = [];

  List<RemoteMessage> get messages => _messages;

  // Hàm thêm thông báo mới
  void addMessage(RemoteMessage message) {
    // Chỉ thêm nếu có nội dung hiển thị
    if (message.notification != null) {
      _messages.add(message);
      notifyListeners(); // 🔔 Báo cho UI cập nhật ngay lập tức
    }
  }

  // Hàm xóa tất cả (nếu cần)
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}