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
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ProfileService _profileService = ProfileService();
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Hàm tải dữ liệu (tách ra để dùng lại khi Refresh)
  Future<void> _loadData() async {
    setState(() {
      _profileFuture = _profileService.getMyProfile();
    });
  }

  String _formatRoles(List<dynamic> roles) {
    return roles.map((role) => role['role_name']).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lỗi tải hồ sơ',
                      style: TextStyle(color: Colors.red)),
                  ElevatedButton(
                      onPressed: _loadData, child: const Text("Thử lại"))
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData)
          return const Scaffold(body: Center(child: Text('Không có dữ liệu')));

        final user = snapshot.data!;

        // 🚀 SỬA LỖI: Lấy đúng key từ Backend (greenPoints hoặc green_points)
        final points = user['greenPoints'] ?? user['green_points'] ?? 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F7F2),
          // 🚀 TÍNH NĂNG MỚI: Kéo xuống để làm mới (RefreshIndicator)
          // Giúp cập nhật điểm số sau khi đi đường về
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              physics:
                  const AlwaysScrollableScrollPhysics(), // Luôn cho phép cuộn để refresh
              children: [
                const SizedBox(height: 8),
                // Edit Profile Button (top right)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(userData: user),
                            ),
                          );
                          if (result == true) _loadData();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Chỉnh sửa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Avatar with shadow
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Color(0xFF2E7D32),
                      child: Icon(Icons.person_rounded,
                          size: 60, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tên
                Text(
                  user['full_name'] ?? 'Chưa cập nhật tên',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 12),

                // Role
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatRoles(user['roles'] ?? []),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 🚀 THẺ ĐIỂM XANH (GAMIFICATION)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Điểm Xanh Tích Lũy",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text("Green Points",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.eco,
                              color: Colors.yellowAccent, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            "$points", // 👈 Hiển thị biến points đã fix lỗi
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Thông tin chi tiết
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.email_rounded,
                              color: Color(0xFF2E7D32)),
                        ),
                        title: const Text('Email',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(user['email'] ?? '...'),
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.phone_rounded,
                              color: Color(0xFF2E7D32)),
                        ),
                        title: const Text('Số điện thoại',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(user['phone_number'] ?? 'Chưa cập nhật'),
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.apartment_rounded,
                              color: Color(0xFF2E7D32)),
                        ),
                        title: const Text('Cơ quan / Đơn vị',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(user['agency_department'] ?? 'Không có'),
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.health_and_safety_rounded,
                              color: Color(0xFF2E7D32)),
                        ),
                        title: const Text('Nhóm sức khỏe',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(user['health_group'] ?? 'normal'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
