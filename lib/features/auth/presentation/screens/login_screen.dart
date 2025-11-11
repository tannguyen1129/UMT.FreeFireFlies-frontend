import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_provider.dart';
import '../../services/auth_service.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  Future<void> _login(BuildContext context) async { // context từ Builder
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 🚀 LƯU TRỮ TRẠNG THÁI TRƯỚC KHI AWAIT (AN TOÀN)
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(this.context);

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String token = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      // 1. KÍCH HOẠT PROVIDER (Điều hướng xảy ra ở đây)
      if (!mounted) return;
      authProvider.loginSuccess(token);

      // 2. HIỂN THỊ SNACKBAR (Dùng biến đã lưu)
      // Chạy sau khi build frame này hoàn tất (để SnackBar hiện trên HomeScreen)
      Future.microtask(() {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công!')),
        );
      });

    } catch (e) {
      if (!mounted) return;

      // 🚀 NẾU LỖI, HÃY TẮT LOADING VÀ HIỂN THỊ LỖI
      setState(() {
        _isLoading = false;
      });

      // Dùng biến đã lưu để hiển thị lỗi
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập Green-AQI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ... (TextFormField Email và Password giữ nguyên)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Vui lòng nhập email hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 8) {
                    return 'Mật khẩu phải có ít nhất 8 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // --- Nút Đăng nhập ---
              _isLoading
                  ? const CircularProgressIndicator()
                  : Builder(
                builder: (innerContext) => ElevatedButton(
                  onPressed: () => _login(innerContext), // 👈 CHUYỂN INNER CONTEXT
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Đăng nhập'),
                ),
              ),
              // ... (Nút Đăng ký giữ nguyên)
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // TODO: Điều hướng sang màn hình Đăng ký
                },
                child: const Text('Chưa có tài khoản? Đăng ký ngay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}