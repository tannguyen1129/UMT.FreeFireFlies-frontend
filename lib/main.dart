import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Đã import

// Import các màn hình và provider
import 'features/auth/presentation/providers/auth_state_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'navigation/navigation_shell.dart';

// 🚀 HÀM XỬ LÝ TIN NHẮN KHI APP TẮT (BACKGROUND)
// Phải để ở top-level (ngoài hàm main)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🌙 Nhận thông báo ngầm: ${message.messageId}");
}

void main() async {
  // 1. Đảm bảo Flutter binding đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. 🚀 FIX QUAN TRỌNG: Load file .env TRƯỚC KHI làm bất cứ gì khác
    // (Để ApiClient có thể đọc được IP)
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ Không tìm thấy file .env (Hoặc lỗi load), sẽ dùng cấu hình mặc định.");
  }

  try {
    // 3. Khởi tạo Firebase
    await Firebase.initializeApp();

    // Đăng ký hàm xử lý nền
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Xin quyền thông báo
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Quyền thông báo: ${settings.authorizationStatus}');

    // 5. Đăng ký vào Topic chung
    await messaging.subscribeToTopic('general_alerts');
    print("✅ Đã đăng ký nhận tin từ topic: general_alerts");

  } catch (e) {
    print("❌ Lỗi khởi tạo Firebase: $e");
    // App vẫn sẽ chạy tiếp dù Firebase lỗi, để bạn còn debug được UI
  }

  runApp(
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
    final authState = Provider.of<AuthStateProvider>(context);

    return MaterialApp(
      title: 'Green-AQI Navigator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      // Điều hướng dựa trên trạng thái đăng nhập
      home: authState.isAuthenticated
          ? const NavigationShell()
          : const LoginScreen(),
    );
  }
}