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
import '../providers/auth_state_provider.dart';
import '../../services/auth_service.dart';
import 'dart:async';
import 'register_screen.dart';

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

  Future<void> _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    final scaffold = ScaffoldMessenger.of(this.context);

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final token = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      authProvider.loginSuccess();

      // Hiển thị SnackBar sau khi điều hướng
      Future.microtask(() {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Đăng nhập thành công!')),
        );
      });

    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      scaffold.showSnackBar(
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
      appBar: AppBar(title: const Text('Đăng nhập Green-AQI')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Email ---
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

              // --- Password ---
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

              // --- Button Login ---
              _isLoading
                  ? const CircularProgressIndicator()
                  : Builder(
                builder: (innerContext) => ElevatedButton(
                  onPressed: () => _login(innerContext),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Đăng nhập'),
                ),
              ),

              const SizedBox(height: 20),

              // --- Link Đăng ký ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Chưa có tài khoản?"),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text("Đăng ký ngay"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
