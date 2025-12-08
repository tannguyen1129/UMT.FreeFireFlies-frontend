import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import các màn hình và provider
import 'features/auth/presentation/providers/auth_state_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'navigation/navigation_shell.dart';

// 👇 Import NotificationProvider
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
    // 🚀 Dùng MultiProvider để bọc cả Auth và Notification Provider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStateProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()), // 👈 Thêm cái này
      ],
      child: const MyApp(),
    ),
  );
}

// 🔄 Đổi thành StatefulWidget để Init listener
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
    // 1. Xử lý khi mở App từ thông báo (khi App đã tắt hẳn)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. Xử lý khi mở App từ thông báo (khi App chạy ngầm)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // 3. 🔔 QUAN TRỌNG: Lắng nghe tin nhắn khi App đang mở (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Nhận tin nhắn Foreground: ${message.notification?.title}');

      // Lưu tin nhắn vào Provider để các màn hình khác (NavigationShell, NotificationScreen) dùng chung
      if (message.notification != null) {
        Provider.of<NotificationProvider>(context, listen: false).addMessage(message);
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    // Logic điều hướng khi bấm vào thông báo (nếu cần)
    print("👆 Người dùng đã bấm vào thông báo: ${message.data}");

    // Cũng lưu vào Provider luôn để hiển thị
    Provider.of<NotificationProvider>(context, listen: false).addMessage(message);
  }

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