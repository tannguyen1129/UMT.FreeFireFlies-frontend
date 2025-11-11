import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../services/user_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _userProfileFuture;
  final UserDataService _userDataService = UserDataService();

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _userDataService.fetchUserProfile();
  }

  void _handleLogout() {
    Provider.of<AuthStateProvider>(context, listen: false).logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Green-AQI Navigator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Xử lý lỗi (ví dụ: token hết hạn)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (snapshot.error.toString().contains('hết hạn')) {
                _handleLogout();
              }
            });
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ĐĂNG NHẬP THÀNH CÔNG!'),
                  const SizedBox(height: 20),
                  Text('Xin chào: ${user['full_name']}'), // Lấy tên từ hồ sơ
                  Text('Email: ${user['email']}'),
                  Text('Vai trò: ${user['roles'][0]['role_name']}'),
                  const SizedBox(height: 30),
                  const Text('TODO: Tích hợp Bản đồ Chính ở đây.'),
                ],
              ),
            );
          }
          return const Center(child: Text('Không có dữ liệu người dùng.'));
        },
      ),
    );
  }
}