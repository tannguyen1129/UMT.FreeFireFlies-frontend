import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 👈 Import FCM

import '../features/map/presentation/screens/home_screen.dart';
import '../features/incidents/presentation/screens/my_incidents_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/achievements_screen.dart';
import '../features/auth/presentation/providers/auth_state_provider.dart';
import '../features/map/presentation/screens/notification_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({Key? key}) : super(key: key);

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  // 🚀 BIẾN QUẢN LÝ THÔNG BÁO
  int _unreadCount = 0;
  final List<RemoteMessage> _messages = [];

  // 🎨 Modern Color Palette
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentGreen = Color(0xFF66BB6A);
  static const Color bgLight = Color(0xFFF1F8F4);

  @override
  void initState() {
    super.initState();

    // 🚀 LẮNG NGHE TIN NHẮN ĐỂ CẬP NHẬT BADGE
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (mounted) {
          setState(() {
            _messages.insert(0, message); // Thêm tin mới lên đầu

            // Chỉ tăng số đếm nếu không đang đứng ở tab Thông báo
            if (_selectedIndex != 2) {
              _unreadCount++;
            }
          });
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Nếu bấm vào tab Thông báo (index 2) -> Xóa badge
      if (index == 2) {
        _unreadCount = 0;
      }
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout_outlined, color: primaryGreen),
            SizedBox(width: 12),
            Text('Xác nhận đăng xuất'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthStateProvider>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Danh sách trang (Phải để trong build để truyền _messages)
    final List<Widget> pages = [
      const HomeScreen(),
      const MyIncidentsScreen(),
      NotificationScreen(messages: _messages), // 👈 Tab Thông báo (Index 2)
      const AchievementsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      // 🎨 Modern AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, accentGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.eco_outlined, size: 26),
                SizedBox(width: 10),
                Text(
                  'Green-AQI',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
            actions: [
              // Đã bỏ nút chuông ở đây vì chuyển xuống dưới
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 24),
                tooltip: 'Đăng xuất',
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),

      // 🌈 Body
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [bgLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),

      // 🎯 Bottom Navigation Bar (5 Tabs)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: primaryGreen,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
            showUnselectedLabels: true,
            elevation: 0,
            items: [
              _buildNavItem(Icons.map_outlined, Icons.map, 'Bản đồ', 0),
              _buildNavItem(Icons.warning_amber_outlined, Icons.warning_amber, 'Báo cáo', 1),

              // 🚀 TAB THÔNG BÁO (CÓ BADGE)
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 2 ? primaryGreen.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _selectedIndex == 2 ? Icons.notifications : Icons.notifications_outlined,
                        size: 28,
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                  ],
                ),
                label: 'Thông báo',
              ),

              _buildNavItem(Icons.emoji_events_outlined, Icons.emoji_events, 'Thành tích', 3),
              _buildNavItem(Icons.person_outline, Icons.person, 'Hồ sơ', 4),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Custom Navigation Item Helper
  BottomNavigationBarItem _buildNavItem(IconData outlinedIcon, IconData filledIcon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(isSelected ? filledIcon : outlinedIcon, size: 28),
      ),
      label: label,
    );
  }
}