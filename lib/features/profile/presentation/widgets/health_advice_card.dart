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
import '../../../../core/utils/health_advisor.dart'; // Import file logic y tế

class HealthAdviceCard extends StatelessWidget {
  final double pm25;
  final String userHealthGroup;

  const HealthAdviceCard({
    Key? key,
    required this.pm25,
    required this.userHealthGroup,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Gọi logic y tế để lấy lời khuyên, màu sắc, icon
    final advice = HealthAdvisor.getAdvice(pm25, userHealthGroup);
    final groupName = HealthAdvisor.getGroupName(userHealthGroup);

    return Card(
      elevation: 6,
      color: advice.color.withOpacity(0.95), // Màu nền theo mức độ nguy hiểm
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon cảnh báo
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(advice.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),

            // Nội dung lời khuyên
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tiêu đề nhỏ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "LỜI KHUYÊN CHO: ${groupName.toUpperCase()}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Nội dung chính
                  Text(
                    advice.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}