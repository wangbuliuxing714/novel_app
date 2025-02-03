import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';

class ChapterDetailScreen extends StatelessWidget {
  final Chapter chapter = Get.arguments;
  final _novelController = Get.find<NovelController>();
  final _themeController = Get.find<ThemeController>();

  ChapterDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('第${chapter.number}章：${chapter.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Get.toNamed('/chapter_edit', arguments: chapter);
            },
          ),
        ],
      ),
      body: Obx(() {
        // 获取最新的章节数据
        final currentChapter = _novelController.getChapter(chapter.number) ?? chapter;
        
        return Container(
          color: _themeController.getAdjustedBackgroundColor(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第${currentChapter.number}章：${currentChapter.title}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  currentChapter.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
} 