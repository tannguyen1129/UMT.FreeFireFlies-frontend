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