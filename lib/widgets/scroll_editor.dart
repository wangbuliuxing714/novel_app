import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/editor_controller.dart';

class ScrollEditor extends StatelessWidget {
  const ScrollEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditorController>();

    return Column(
      children: [
        // 工具栏
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
              // 字体大小调节
              IconButton(
                icon: const Icon(Icons.text_decrease),
                onPressed: () => controller.changeFontSize(-2),
                tooltip: '减小字体',
              ),
              IconButton(
                icon: const Icon(Icons.text_increase),
                onPressed: () => controller.changeFontSize(2),
                tooltip: '增大字体',
              ),
              const VerticalDivider(),
              // 保存按钮
              Obx(() => IconButton(
                icon: Icon(
                  Icons.save,
                  color: controller.hasUnsavedChanges() 
                    ? Theme.of(context).colorScheme.primary 
                    : null,
                ),
                onPressed: controller.saveContent,
                tooltip: '保存',
              )),
            ],
          ),
        ),
        
        // 编辑区域
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 标题
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: TextField(
                      controller: controller.titleController,
                      decoration: const InputDecoration(
                        hintText: '请输入章节标题',
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // 内容编辑区
                  Obx(() => TextField(
                    controller: controller.contentController,
                    decoration: const InputDecoration(
                      hintText: '开始创作你的故事...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    style: TextStyle(
                      fontSize: controller.fontSize.value,
                      height: 1.8,
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
        
        // 底部状态栏
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              // 字数统计
              Obx(() => Text('字数：${controller.wordCount}')),
              const Spacer(),
              // 保存状态
              Obx(() {
                if (controller.isSaving.value) {
                  return const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('保存中...'),
                    ],
                  );
                }
                return Text(
                  controller.lastSaveTime.value.isEmpty
                    ? '未保存'
                    : '上次保存：${controller.lastSaveTime}',
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
} 