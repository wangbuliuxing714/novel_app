import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  final authController = Get.find<AuthController>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _isRegister = false.obs;

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_isRegister.value ? '注册' : '登录')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Obx(() {
              if (_isRegister.value) {
                return Column(
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                );
              }
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_isRegister.value) {
                    if (_usernameController.text.isEmpty ||
                        _emailController.text.isEmpty ||
                        _passwordController.text.isEmpty) {
                      Get.snackbar('错误', '请填写完整信息');
                      return;
                    }
                    authController.register(
                      _usernameController.text,
                      _emailController.text,
                      _passwordController.text,
                    );
                  } else {
                    if (_usernameController.text.isEmpty ||
                        _passwordController.text.isEmpty) {
                      Get.snackbar('错误', '请填写完整信息');
                      return;
                    }
                    authController.login(
                      _usernameController.text,
                      _passwordController.text,
                    );
                  }
                },
                child: Obx(() => Text(_isRegister.value ? '注册' : '登录')),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _isRegister.value = !_isRegister.value,
              child: Obx(() => Text(_isRegister.value ? '已有账号？去登录' : '没有账号？去注册')),
            ),
          ],
        ),
      ),
    );
  }
}