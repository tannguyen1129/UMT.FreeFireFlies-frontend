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
    _profileFuture = _profileService.getMyProfile();
  }

  // Helper để hiển thị Roles
  String _formatRoles(List<dynamic> roles) {
    return roles.map((role) => role['role_name']).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho KeepAlive

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {

        // 1. Đang tải
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Lỗi
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Lỗi tải hồ sơ:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        // 3. Không có dữ liệu
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Không tìm thấy dữ liệu hồ sơ.')),
          );
        }

        // 4. Thành công -> Hiển thị giao diện chính
        final user = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hồ sơ Cá nhân'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Chỉnh sửa thông tin',
                onPressed: () async {
                  // Chuyển sang màn hình sửa
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EditProfileScreen(userData: user)
                    ),
                  );

                  // Nếu sửa thành công (trả về true), reload lại profile
                  if (result == true) {
                    setState(() {
                      _profileFuture = _profileService.getMyProfile();
                    });
                  }
                },
              )
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Ảnh đại diện (Avatar)
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),

              // Tên đầy đủ
              Text(
                user['full_name'] ?? 'Chưa cập nhật tên',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Quyền (Roles)
              Center(
                child: Chip(
                  label: Text(_formatRoles(user['roles'] ?? [])),
                  backgroundColor: Colors.green.shade100,
                ),
              ),
              const Divider(height: 32),

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
                      title: const Text('Cơ quan/Đơn vị'),
                      subtitle: Text(user['agency_department'] ?? 'Không có'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}