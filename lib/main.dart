import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 👈 Import dotenv

// Import các màn hình và provider
import 'features/auth/presentation/providers/auth_state_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'navigation/navigation_shell.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nếu cần dùng Firebase trong background handler thì phải init lại
  await Firebase.initializeApp();
  print("🌙 Nhận thông báo ngầm (Background): ${message.messageId}");
  // Ở đây bạn có thể xử lý logic ngầm (ví dụ lưu local storage) nhưng không update UI được
}

void main() async {
  // 1. Đảm bảo Flutter binding đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // (Để ApiClient có thể đọc được IP ngay khi app khởi động)
    await dotenv.load(fileName: ".env");
    print("✅ Đã load .env thành công");
  } catch (e) {
    print("⚠️ Không tìm thấy file .env (Hoặc lỗi load), sẽ dùng cấu hình mặc định trong code.");
  }

  try {
    // 3. Khởi tạo Firebase
    await Firebase.initializeApp();

    // Đăng ký hàm xử lý nền
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Xin quyền thông báo (Cho Android 13+ và iOS)
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Quyền thông báo: ${settings.authorizationStatus}');

    // 5. Đăng ký vào Topic chung (Để nhận cảnh báo từ Server)
    await messaging.subscribeToTopic('general_alerts');
    print("✅ Đã đăng ký nhận tin từ topic: general_alerts");

    // 6. Lắng nghe tin nhắn khi đang mở App (Foreground) - Global Listener
    // (Lưu ý: Để hiện UI đẹp, ta nên lắng nghe thêm ở từng màn hình như HomeScreen)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Nhận tin nhắn Foreground (Global): ${message.notification?.title}');
      if (message.notification != null) {
        print('Nội dung: ${message.notification?.body}');
      }
    });

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
        useMaterial3: true, // Giao diện hiện đại hơn
      ),
      // Điều hướng dựa trên trạng thái đăng nhập
      home: authState.isAuthenticated
          ? const NavigationShell()
          : const LoginScreen(),
    );
  }
}