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
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import các màn hình và provider
import 'features/auth/presentation/providers/auth_state_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'navigation/navigation_shell.dart';

// Import NotificationProvider
import 'features/notifications/presentation/providers/notification_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🌙 Nhận thông báo ngầm (Background): ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("✅ Đã load .env thành công");
  } catch (e) {
    print("⚠️ Không tìm thấy file .env, dùng mặc định.");
  }

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.subscribeToTopic('general_alerts');
    print("✅ Đã đăng ký nhận tin từ topic: general_alerts");

  } catch (e) {
    print("❌ Lỗi khởi tạo Firebase: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStateProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    setupInteractedMessage();
  }

  Future<void> setupInteractedMessage() async {
    // 1. App tắt hẳn
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. App chạy ngầm
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // 3. App đang mở (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Nhận tin nhắn Foreground: ${message.notification?.title}');
      if (message.notification != null) {
        Provider.of<NotificationProvider>(context, listen: false).addMessage(message);
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    print("👆 Người dùng đã bấm vào thông báo: ${message.data}");
    Provider.of<NotificationProvider>(context, listen: false).addMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe trạng thái từ AuthStateProvider
    final authState = Provider.of<AuthStateProvider>(context);

    return MaterialApp(
      title: 'Green-AQI Navigator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      // 🛡️ LOGIC ĐIỀU HƯỚNG THÔNG MINH (QUAN TRỌNG)
      // Kiểm tra biến isChecking trước.
      // Nếu đang check token -> Hiện Loading xoay vòng.
      // Check xong -> Mới quyết định vào Home hay Login.
      home: authState.isChecking
          ? const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      )
          : (authState.isAuthenticated
          ? const NavigationShell()
          : const LoginScreen()),
    );
  }
}