import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/screens/genre_manager_screen.dart';
import 'package:novel_app/screens/style_manager_screen.dart';
import 'package:novel_app/screens/outline_prompt_screen.dart';

class ModuleRepositoryScreen extends StatelessWidget {
  const ModuleRepositoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模块仓库'),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildModuleCard(
            context,
            icon: Icons.category,
            title: '类型管理',
            description: '管理小说类型和分类',
            onTap: () => Get.to(GenreManagerScreen()),
          ),
          _buildModuleCard(
            context,
            icon: Icons.style,
            title: '写作风格',
            description: '管理写作风格和提示词',
            onTap: () => Get.to(StyleManagerScreen()),
          ),
          _buildModuleCard(
            context,
            icon: Icons.format_list_bulleted,
            title: '大纲提示词',
            description: '管理大纲生成模板',
            onTap: () => Get.to(OutlinePromptScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 