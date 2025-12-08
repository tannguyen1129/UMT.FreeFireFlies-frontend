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
    final myPoints = _myProfile?['greenPoints'] ?? _myProfile?['green_points'] ?? 0;

    // Tính hạng (Level)
    String level = "Tập sự";
    Color badgeColor = Colors.white70;
    if (myPoints > 100) { level = "Chiến binh Xanh"; badgeColor = Colors.cyanAccent; }
    if (myPoints > 500) { level = "Hiệp sĩ Môi trường"; badgeColor = Colors.orangeAccent; }
    if (myPoints > 1000) { level = "Đại sứ Trái Đất"; badgeColor = Colors.yellowAccent; }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thành tích Xanh"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.yellowAccent, size: 60),
                    const SizedBox(height: 10),
                    Text(
                        "$myPoints Điểm",
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    Text(
                        level,
                        style: TextStyle(fontSize: 18, color: badgeColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)
                    ),
                    const Divider(color: Colors.white24, height: 30),

                    // (Phần này có thể làm thật nếu backend hỗ trợ thống kê chi tiết, tạm thời để UI tĩnh cho đẹp)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [Text("12", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Chuyến đi", style: TextStyle(color: Colors.white70))]),
                        Column(children: [Text("45 km", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Quãng đường", style: TextStyle(color: Colors.white70))]),
                        Column(children: [Text("30g", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Bụi giảm", style: TextStyle(color: Colors.white70))]),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Align(alignment: Alignment.centerLeft, child: Text("Bảng Xếp Hạng", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),

              // LEADERBOARD LIST
              _leaderboard.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Chưa có dữ liệu xếp hạng", style: TextStyle(color: Colors.grey)),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _leaderboard.length,
                itemBuilder: (ctx, index) {
                  final user = _leaderboard[index];
                  // 🚀 FIX LỖI HIỂN THỊ ĐIỂM TRONG LIST
                  final uPoints = user['greenPoints'] ?? user['green_points'] ?? 0;
                  final uName = user['full_name'] ?? user['email'] ?? 'Ẩn danh';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index == 0 ? Colors.yellow : (index == 1 ? Colors.grey.shade300 : (index == 2 ? Colors.orange.shade200 : Colors.blue.shade50)),
                        child: Text("${index + 1}", style: TextStyle(color: index < 3 ? Colors.black : Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(uName, style: TextStyle(fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal)),
                      trailing: Text("$uPoints pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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