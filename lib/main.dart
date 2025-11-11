import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/presentation/providers/auth_state_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/map/presentation/screens/home_screen.dart';

void main() {
  runApp(
    // 🚀 BỌC TOÀN BỘ APP BẰNG PROVIDER
    ChangeNotifierProvider(
      create: (context) => AuthStateProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🚀 THEO DÕI TRẠNG THÁI ĐĂNG NHẬP
    final authState = Provider.of<AuthStateProvider>(context);

    return MaterialApp(
      title: 'Green-AQI Navigator',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Điều hướng dựa trên trạng thái (Logged In hay Logged Out)
      home: authState.isAuthenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}