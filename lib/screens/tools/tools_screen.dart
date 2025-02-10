import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/tts_controller.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/models/novel.dart';
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
              ],
            ),
          ),
        ],
      ),
    );
  }
} 