import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/outline_controller.dart';
import 'package:novel_app/screens/chapter_add/chapter_add_screen.dart';
import 'package:novel_app/models/chapter.dart';

class OutlineNavigator extends StatelessWidget {
  const OutlineNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OutlineController>();

    return Column(
      children: [
        // 顶部工具栏
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              const Text('大纲导航', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // 显示添加章节对话框
                  Get.dialog(
                    const ChapterAddScreen(),
                    barrierDismissible: false,
                  );
                },
                tooltip: '添加章节',
              ),
            ],
          ),
        ),
        
        // 大纲列表
        Expanded(
          child: Obx(() => ReorderableListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: controller.chapters.length,
            onReorder: controller.reorderChapters,
            itemBuilder: (context, index) {
              final chapter = controller.chapters[index];
              return _buildChapterTile(
                key: Key(chapter.id),
                chapter: chapter,
                controller: controller,
              );
            },
          )),
        ),
      ],
    );
  }

  Widget _buildChapterTile({
    required Key key,
    required Chapter chapter,
    required OutlineController controller,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: chapter.isSelected ? Get.theme.colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        title: Text(
          chapter.title,
          style: TextStyle(
            color: chapter.isSelected ? Get.theme.colorScheme.onPrimaryContainer : null,
          ),
        ),
        dense: true,
        onTap: () => controller.selectChapter(chapter.id),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('编辑'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除'),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                Get.dialog(
                  AlertDialog(
                    title: const Text('编辑章节标题'),
                    content: TextField(
                      autofocus: true,
                      controller: TextEditingController(text: chapter.title),
                      decoration: const InputDecoration(
                        labelText: '章节标题',
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          controller.updateChapterTitle(chapter.id, value);
                          Get.back();
                        }
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          final textField = Get.find<TextField>();
                          final value = textField.controller?.text ?? '';
                          if (value.isNotEmpty) {
                            controller.updateChapterTitle(chapter.id, value);
                            Get.back();
                          }
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                break;
              case 'delete':
                Get.dialog(
                  AlertDialog(
                    title: const Text('删除章节'),
                    content: Text('确定要删除章节"${chapter.title}"吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.removeChapter(chapter.id);
                          Get.back();
                        },
                        child: const Text('确定'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
                break;
            }
          },
        ),
      ),
    );
  }
} 