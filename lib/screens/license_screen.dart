import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/services/license_service.dart';

class LicenseScreen extends StatelessWidget {
  final _licenseController = TextEditingController();
  final _licenseService = Get.find<LicenseService>();

  LicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'AI小说生成器',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '请输入许可证密钥以继续使用',
                style: TextStyle(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: '许可证密钥',
                  hintText: '请输入您的许可证密钥',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final success = await _licenseService.activateLicense(
                    _licenseController.text.trim(),
                  );
                  
                  if (success) {
                    Get.offAllNamed('/');  // 导航到主页
                  } else {
                    Get.snackbar(
                      '错误',
                      '无效的许可证密钥',
                      backgroundColor: Colors.red.withOpacity(0.1),
                      duration: const Duration(seconds: 3),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('激活'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // 这里可以添加获取许可证的链接
                  // 比如发送邮件或跳转到购买页面
                },
                child: const Text('如何获取许可证？'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 