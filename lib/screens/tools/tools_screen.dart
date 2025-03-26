import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/tts_controller.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/screens/character_generator_screen.dart';
import 'package:novel_app/screens/background_generator_screen.dart';
import 'package:novel_app/screens/knowledge_base_screen.dart';
import 'package:novel_app/screens/debug/conversation_debug_screen.dart';
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
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('会话历史调试'),
                  subtitle: const Text('查看和管理AI对话历史记录'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showPasswordDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showPasswordDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    final RxBool isPasswordIncorrect = false.obs;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.orange),
            const SizedBox(width: 10),
            const Text('需要密码'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('会话历史调试功能受密码保护，请输入密码继续'),
            const SizedBox(height: 20),
            Obx(() => TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: '密码',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                errorText: isPasswordIncorrect.value ? '密码错误，请重试' : null,
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == '147258') {
                Navigator.pop(context);
                Get.to(() => const ConversationDebugScreen());
              } else {
                isPasswordIncorrect.value = true;
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
} 