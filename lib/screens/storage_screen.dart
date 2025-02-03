import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/models/novel.dart';

class StorageScreen extends StatelessWidget {
  final novelController = Get.find<NovelController>();

  StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已生成章节'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('清空所有章节'),
                  content: const Text('确定要清空所有已生成的章节吗？此操作不可恢复。'),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        novelController.clearAllChapters();
                        Get.back();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Obx(() {
        if (novelController.generatedChapters.isEmpty) {
          return const Center(
            child: Text('还没有生成任何章节'),
          );
        }

        return ListView.builder(
          itemCount: novelController.generatedChapters.length,
          itemBuilder: (context, index) {
            final chapter = novelController.generatedChapters[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('第${chapter.number}章：${chapter.title}'),
                subtitle: Text('字数：${chapter.content.length}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // 编辑章节
                        Get.toNamed('/chapter_edit', arguments: chapter);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        Get.dialog(
                          AlertDialog(
                            title: const Text('删除章节'),
                            content: Text('确定要删除第${chapter.number}章吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  novelController.deleteChapter(chapter.number);
                                  Get.back();
                                },
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  // 查看章节详情
                  Get.toNamed('/chapter_detail', arguments: chapter);
                },
              ),
            );
          },
        );
      }),
    );
  }
} 