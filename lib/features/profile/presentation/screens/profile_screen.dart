import 'package:flutter/material.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {

  // Giữ trạng thái khi chuyển tab
  @override
  bool get wantKeepAlive => true;

  final ProfileService _profileService = ProfileService();
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileService.getMyProfile();
  }

  // Helper để hiển thị Roles (Quyền)
  String _formatRoles(List<dynamic> roles) {
    return roles.map((role) => role['role_name']).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Bắt buộc cho KeepAlive

    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        // 1. Trạng thái Đang tải
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Trạng thái Lỗi
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Lỗi tải hồ sơ:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // 3. Trạng thái Không có dữ liệu
        if (!snapshot.hasData) {
          return const Center(child: Text('Không tìm thấy dữ liệu hồ sơ.'));
        }

        // 4. Trạng thái Thành công (Hiển thị dữ liệu)
        final user = snapshot.data!;

        return ListView(
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
              style: Theme.of(context).textTheme.headlineSmall,
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
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(user['email'] ?? '...'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Số điện thoại'),
                    subtitle: Text(user['phone_number'] ?? 'Chưa cập nhật'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.apartment),
                    title: const Text('Cơ quan (Nếu có)'),
                    subtitle: Text(user['agency_department'] ?? 'Không có'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}