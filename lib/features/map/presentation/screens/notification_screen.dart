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
import 'package:provider/provider.dart'; // 👈 Import Provider
import '../../../notifications/presentation/providers/notification_provider.dart'; // 👈 Import đường dẫn đúng

class NotificationScreen extends StatelessWidget {
  // Bỏ tham số messages trong constructor đi vì ta sẽ lấy từ Provider
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎧 Lắng nghe dữ liệu từ Provider
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final messages = notificationProvider.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        actions: [
          // Nút xóa nhanh để test
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => notificationProvider.clearMessages(),
          )
        ],
      ),
      body: messages.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 60, color: Colors.grey),
            Text("Chưa có thông báo nào"),
          ],
        ),
      )
          : ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          // Đảo ngược để tin mới nhất lên đầu
          final msg = messages[messages.length - 1 - index];

          return Card(
            // ... (Giữ nguyên code UI Card của bạn) ...
            child: ListTile(
              title: Text(msg.notification?.title ?? 'Hệ thống'),
              subtitle: Text(msg.notification?.body ?? ''),
              // ...
            ),
          );
        },
      ),
    );
  }
}