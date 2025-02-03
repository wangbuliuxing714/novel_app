import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '岱宗文脉',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI驱动的小说创作助手',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('首页'),
            onTap: () {
              Get.back();
              Get.toNamed('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('存储管理'),
            onTap: () {
              Get.back();
              Get.toNamed('/storage');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('实时在线编辑'),
            subtitle: const Text('多栏协同创作模式'),
            onTap: () {
              Get.back();
              Get.toNamed('/realtime_editor');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {
              Get.back();
              Get.toNamed('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('帮助'),
            onTap: () {
              Get.back();
              Get.toNamed('/help');
            },
          ),
        ],
      ),
    );
  }
} 