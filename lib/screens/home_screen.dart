import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/auth_controller.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/models/genre_category.dart';

class HomeScreen extends StatelessWidget {
  final _novelController = Get.find<NovelController>();
  final _themeController = Get.find<ThemeController>();

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('岱宗文脉'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authController.logout(),
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: () {
              Get.toNamed('/storage');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主题切换按钮
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Obx(() => Switch(
                    value: _themeController.isEyeProtectionMode,
                    onChanged: (_) => _themeController.toggleTheme(),
                  )),
                  const Text('护眼模式'),
                ],
              ),
            ),
            const Text(
              '欢迎使用岱宗文脉\n汲取泰山灵气，承载文脉传承',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // TODO: 跳转到生成器页面
              },
              child: const Text('开始创作'),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: '小说标题',
                hintText: '请输入小说标题',
              ),
              onChanged: _novelController.updateTitle,
            ),
          ],
        ),
      ),
    );
  }
} 