import 'package:flutter/material.dart';
import '../../services/profile_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lỗi tải hồ sơ', style: TextStyle(color: Colors.red)),
                  ElevatedButton(onPressed: _loadData, child: const Text("Thử lại"))
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) return const Scaffold(body: Center(child: Text('Không có dữ liệu')));

        final user = snapshot.data!;

        // 🚀 SỬA LỖI: Lấy đúng key từ Backend (greenPoints hoặc green_points)
        final points = user['greenPoints'] ?? user['green_points'] ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hồ sơ Cá nhân'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Chỉnh sửa thông tin',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditProfileScreen(userData: user)),
                  );
                  if (result == true) _loadData(); // Reload nếu có sửa
                },
              )
            ],
          ),
          // 🚀 TÍNH NĂNG MỚI: Kéo xuống để làm mới (RefreshIndicator)
          // Giúp cập nhật điểm số sau khi đi đường về
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(), // Luôn cho phép cuộn để refresh
              children: [
                // Avatar
                const Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),

                // Tên
                Text(
                  user['full_name'] ?? 'Chưa cập nhật tên',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Role
                Center(
                  child: Chip(
                    label: Text(_formatRoles(user['roles'] ?? [])),
                    backgroundColor: Colors.green.shade100,
                  ),
                ),
                const Divider(height: 32),

                // 🚀 THẺ ĐIỂM XANH (GAMIFICATION)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.teal, Colors.green]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Điểm Xanh Tích Lũy", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text("Green Points", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.eco, color: Colors.yellowAccent, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            "$points", // 👈 Hiển thị biến points đã fix lỗi
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Thông tin chi tiết
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email, color: Colors.blue),
                        title: const Text('Email'),
                        subtitle: Text(user['email'] ?? '...'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone, color: Colors.green),
                        title: const Text('Số điện thoại'),
                        subtitle: Text(user['phone_number'] ?? 'Chưa cập nhật'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.apartment, color: Colors.orange),
                        title: const Text('Cơ quan / Đơn vị'),
                        subtitle: Text(user['agency_department'] ?? 'Không có'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.health_and_safety, color: Colors.redAccent),
                        title: const Text('Nhóm sức khỏe'),
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