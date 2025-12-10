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
import '../../services/profile_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _myProfile;
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 🚀 Gọi song song 2 API để tiết kiệm thời gian
      final results = await Future.wait([
        _profileService.getMyProfile(),
        _profileService.getLeaderboard(),
      ]);

      if (mounted) {
        setState(() {
          _myProfile = results[0] as Map<String, dynamic>;
          _leaderboard = results[1] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 🚀 FIX LỖI HIỂN THỊ ĐIỂM CỦA TÔI (Bắt cả 2 trường hợp key)
    final myPoints =
        _myProfile?['greenPoints'] ?? _myProfile?['green_points'] ?? 0;

    // Tính hạng (Level)
    String level = "Tập sự";
    Color badgeColor = Colors.white70;
    if (myPoints > 100) {
      level = "Chiến binh Xanh";
      badgeColor = Colors.cyanAccent;
    }
    if (myPoints > 500) {
      level = "Hiệp sĩ Môi trường";
      badgeColor = Colors.orangeAccent;
    }
    if (myPoints > 1000) {
      level = "Đại sứ Trái Đất";
      badgeColor = Colors.yellowAccent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      // 🚀 THÊM KÉO ĐỂ LÀM MỚI
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // CARD TỔNG KẾT
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.yellowAccent, size: 60),
                    const SizedBox(height: 10),
                    Text("$myPoints Điểm",
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(level,
                        style: TextStyle(
                            fontSize: 18,
                            color: badgeColor,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold)),
                    const Divider(color: Colors.white24, height: 30),

                    // (Phần này có thể làm thật nếu backend hỗ trợ thống kê chi tiết, tạm thời để UI tĩnh cho đẹp)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          Text("12",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text("Chuyến đi",
                              style: TextStyle(color: Colors.white70))
                        ]),
                        Column(children: [
                          Text("45 km",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text("Quãng đường",
                              style: TextStyle(color: Colors.white70))
                        ]),
                        Column(children: [
                          Text("30g",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text("Bụi giảm",
                              style: TextStyle(color: Colors.white70))
                        ]),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Bảng Xếp Hạng",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // LEADERBOARD LIST
              _leaderboard.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Chưa có dữ liệu xếp hạng",
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _leaderboard.length,
                      itemBuilder: (ctx, index) {
                        final user = _leaderboard[index];
                        // 🚀 FIX LỖI HIỂN THỊ ĐIỂM TRONG LIST
                        final uPoints =
                            user['greenPoints'] ?? user['green_points'] ?? 0;
                        final uName =
                            user['full_name'] ?? user['email'] ?? 'Ẩn danh';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF2E7D32).withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: index == 0
                                    ? const LinearGradient(colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500)
                                      ])
                                    : (index == 1
                                        ? LinearGradient(colors: [
                                            Colors.grey.shade300,
                                            Colors.grey.shade400
                                          ])
                                        : (index == 2
                                            ? const LinearGradient(colors: [
                                                Color(0xFFCD7F32),
                                                Color(0xFFD2691E)
                                              ])
                                            : const LinearGradient(colors: [
                                                Color(0xFF2E7D32),
                                                Color(0xFF66BB6A)
                                              ]))),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                    color:
                                        index < 3 ? Colors.white : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              uName,
                              style: TextStyle(
                                fontWeight: index == 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2E7D32),
                                    Color(0xFF66BB6A)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "$uPoints pts",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
            ],
          ),
        ),
      ),
    );
  }
}
