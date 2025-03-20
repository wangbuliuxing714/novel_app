import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/tts_controller.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/screens/character_generator_screen.dart';
import 'package:novel_app/screens/background_generator_screen.dart';
import 'package:novel_app/screens/knowledge_base_screen.dart';
import 'package:novel_app/screens/tools/novel_chat_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final novelController = Get.find<NovelController>();
    final ttsController = Get.find<TTSController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('工具广场'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.record_voice_over),
                  title: const Text('文本转语音'),
                  subtitle: const Text('将小说转换为语音'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Get.toNamed('/tts'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('小说对话'),
                  subtitle: const Text('与小说角色进行互动对话'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Get.to(() => const NovelChatScreen()),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('角色生成器'),
                  subtitle: const Text('自动生成小说角色'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Get.to(() => const CharacterGeneratorScreen()),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.landscape),
                  title: const Text('背景生成器'),
                  subtitle: const Text('自动生成故事背景和世界观'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Get.to(() => const BackgroundGeneratorScreen()),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: const Text('知识库管理'),
                  subtitle: const Text('管理创作参考资料和知识'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Get.to(() => KnowledgeBaseScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 