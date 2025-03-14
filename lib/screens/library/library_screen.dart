import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/screens/novel_detail_screen.dart';
import 'package:novel_app/services/export_service.dart';
import 'package:novel_app/screens/novel_continue/novel_continue_screen.dart';
import 'package:novel_app/screens/import_screen.dart';

class LibraryScreen extends GetView<NovelController> {
  final _exportService = ExportService();
  
  LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: '导入小说',
            onPressed: () => Get.to(() => const ImportScreen()),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.novels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '书库空空如也',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '去生成一本新小说吧',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.novels.length,
          itemBuilder: (context, index) {
            final novel = controller.novels[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () => Get.to(() => NovelDetailScreen(novel: novel)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  novel.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  novel.genre,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'continue',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_note),
                                    SizedBox(width: 8),
                                    Text('续写'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.file_download),
                                    SizedBox(width: 8),
                                    Text('导出'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline),
                                    SizedBox(width: 8),
                                    Text('删除'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'continue':
                                  Get.to(() => NovelContinueScreen(novel: novel));
                                  break;
                                case 'export':
                                  _showExportDialog(context, novel);
                                  break;
                                case 'delete':
                                  _showDeleteDialog(context, novel);
                                  break;
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${novel.chapters.length}章',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '字数：${novel.wordCount}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            novel.createTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _showExportDialog(BuildContext context, Novel novel) {
    String selectedFormat = 'txt';
    final selectedChapters = <Chapter>{}.obs;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出小说'),
        content: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: double.maxFinite,
            child: Column(
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
                const Divider(),
                const Text('选择章节：'),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('全选'),
                          value: selectedChapters.length == novel.chapters.length,
                          onChanged: (checked) {
                            if (checked == true) {
                              selectedChapters.addAll(novel.chapters);
                            } else {
                              selectedChapters.clear();
                            }
                          },
                        ),
                        const Divider(),
                        ...novel.chapters.map((chapter) => Obx(() => CheckboxListTile(
                          title: Text('第${chapter.number}章：${chapter.title}'),
                          value: selectedChapters.contains(chapter),
                          onChanged: (checked) {
                            if (checked == true) {
                              selectedChapters.add(chapter);
                            } else {
                              selectedChapters.remove(chapter);
                            }
                          },
                        ))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
              
              if (selectedChapters.isEmpty) {
                Get.snackbar('提示', '请选择要导出的章节');
                return;
              }

              // 显示加载对话框
              Get.dialog(
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在导出...'),
                        ],
                      ),
                    ),
                  ),
                ),
                barrierDismissible: false,
              );

              try {
                final result = await _exportService.exportNovel(
                  novel,
                  selectedFormat,
                  selectedChapters: selectedChapters.toList(),
                );
                
                Get.back(); // 关闭加载对话框
                
                Get.snackbar(
                  '导出结果',
                  result,
                  duration: const Duration(seconds: 5),
                );
              } catch (e) {
                Get.back(); // 关闭加载对话框
                Get.snackbar('错误', '导出失败：$e');
              }
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Novel novel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除小说'),
        content: Text('确定要删除《${novel.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteNovel(novel);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 