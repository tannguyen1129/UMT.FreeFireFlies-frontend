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

class HealthAdvice {
  final String message;
  final Color color;
  final IconData icon;

  HealthAdvice(this.message, this.color, this.icon);
}

class HealthAdvisor {
  // PM2.5 thresholds
  static const double GOOD = 12.0;
  static const double MODERATE = 35.4;
  static const double UNHEALTHY_SENSITIVE = 55.4;
  static const double UNHEALTHY = 150.4;

  static HealthAdvice getAdvice(double pm25, String healthGroup) {
    // 1. Mức TỐT (Xanh)
    if (pm25 <= GOOD) {
      return HealthAdvice(
        "Không khí tuyệt vời! Hãy tận hưởng các hoạt động ngoài trời.",
        Colors.green,
        Icons.sentiment_very_satisfied,
      );
    }

    // 2. Mức TRUNG BÌNH (Vàng)
    if (pm25 <= MODERATE) {
      if (healthGroup == 'respiratory') {
        return HealthAdvice(
          "Không khí chấp nhận được. Nhưng hãy mang theo thuốc dự phòng nếu bạn thấy khó chịu.",
          Colors.orange, // Cảnh báo nhẹ cho người bệnh
          Icons.medical_services,
        );
      }
      return HealthAdvice(
        "Chất lượng không khí bình thường. An toàn cho sinh hoạt.",
        Colors.yellow.shade800,
        Icons.sentiment_satisfied,
      );
    }

    // 3. Mức KÉM (Cam) - Nhạy cảm bắt đầu bị ảnh hưởng
    if (pm25 <= UNHEALTHY_SENSITIVE) {
      if (healthGroup == 'respiratory' || healthGroup == 'sensitive') {
        return HealthAdvice(
          "⚠️ CẢNH BÁO: Hạn chế ra ngoài. Đeo khẩu trang chuyên dụng nếu phải di chuyển.",
          Colors.redAccent,
          Icons.warning,
        );
      }
      if (healthGroup == 'athlete') {
        return HealthAdvice(
          "Nên giảm cường độ tập luyện ngoài trời hoặc chuyển vào nhà.",
          Colors.orange,
          Icons.directions_run,
        );
      }
      return HealthAdvice(
        "Nhóm nhạy cảm nên hạn chế ra ngoài. Người thường vẫn an toàn.",
        Colors.orange,
        Icons.info,
      );
    }

    // 4. Mức XẤU & NGUY HẠI (Đỏ/Tím)
    if (healthGroup == 'respiratory' || healthGroup == 'sensitive') {
      return HealthAdvice(
        "⛔ KHẨN CẤP: Tuyệt đối tránh ra ngoài! Đóng kín cửa sổ. Sử dụng máy lọc khí.",
        Colors.red,
        Icons.dangerous,
      );
    }
    return HealthAdvice(
      "Cảnh báo sức khỏe: Mọi người nên hạn chế ra ngoài. Bắt buộc đeo khẩu trang chống bụi mịn.",
      Colors.red,
      Icons.masks,
    );
  }

  static String getGroupName(String key) {
    switch(key) {
      case 'normal': return 'Người bình thường';
      case 'sensitive': return 'Nhạy cảm (Già/Trẻ)';
      case 'respiratory': return 'Bệnh hô hấp (Hen/Phổi)';
      case 'athlete': return 'Vận động viên';
      default: return 'Người bình thường';
    }
  }
}