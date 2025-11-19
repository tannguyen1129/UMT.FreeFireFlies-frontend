import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/map/presentation/screens/home_screen.dart';
import '../features/incidents/presentation/screens/my_incidents_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart'; // 👈 IMPORT MỚI
import '../features/auth/presentation/providers/auth_state_provider.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({Key? key}) : super(key: key);

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  // 🚀 SỬA DANH SÁCH MÀN HÌNH
  static const List<Widget> _pages = <Widget>[
    HomeScreen(), // Tab 0: Bản đồ
    MyIncidentsScreen(), // Tab 1: Báo cáo
    ProfileScreen(), // THAY THẾ PlaceholderScreen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // (Thanh Menu Dưới - Giữ nguyên)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Bản đồ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Báo cáo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}