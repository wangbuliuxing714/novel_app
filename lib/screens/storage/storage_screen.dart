import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/services/export_service.dart';
import 'package:novel_app/models/novel.dart';

class StorageScreen extends StatelessWidget {
  final NovelController _novelController = Get.find();
  final ThemeController _themeController = Get.find();
  final ExportService _exportService = ExportService();

  StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已生成章节'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _showExportDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              final chapters = _novelController.generatedChapters;
              if (chapters.isEmpty) {
                return const Center(
                  child: Text('暂无已生成的章节'),
                );
              }
              return ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  return ListTile(
                    title: Text('第${chapter.number}章：${chapter.title}'),
                    subtitle: Text(
                      chapter.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Get.toNamed('/chapter_detail', arguments: chapter),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _novelController.deleteChapter(chapter.number),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    String selectedFormat = 'txt';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出小说'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择导出格式：'),
              const SizedBox(height: 8),
              ...ExportService.supportedFormats.entries.map(
                (entry) => RadioListTile<String>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: selectedFormat,
                  onChanged: (value) {
                    setState(() => selectedFormat = value!);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final chapters = _novelController.generatedChapters;
              if (chapters.isEmpty) {
                Get.snackbar('导出失败', '没有可导出的章节');
                return;
              }
              
              final novel = Novel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: _novelController.title.value,
                genre: _novelController.selectedGenres.join(','),
                outline: _novelController.currentOutline.value?.chapters.map((c) => c.contentOutline).join('\n\n') ?? '',
                content: chapters.map((c) => c.content).join('\n\n'),
                chapters: chapters,
                createdAt: DateTime.now(),
              );
              final result = await _exportService.exportNovel(
                novel,
                selectedFormat,
                selectedChapters: chapters,
              );
              
              Get.snackbar(
                '导出结果',
                result,
                duration: const Duration(seconds: 5),
              );
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }
} 