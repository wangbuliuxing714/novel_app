import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/chapter_add_controller.dart';

class ChapterAddScreen extends StatelessWidget {
  const ChapterAddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChapterAddController>();
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.8,
          maxWidth: 600,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '添加新章节',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller.titleController,
                decoration: const InputDecoration(
                  labelText: '章节简要情节',
                  border: OutlineInputBorder(),
                  hintText: '请输入章节的主要情节...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // AI扩写按钮
                      Center(
                        child: TextButton.icon(
                          onPressed: controller.generateDetailedOutline,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('AI扩写'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 详细大纲
                      Obx(() => Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '详细大纲',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (controller.detailedOutline.value.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: controller.editDetailedOutline,
                                          tooltip: '编辑',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    controller.detailedOutline.value.isEmpty
                                        ? '点击"AI扩写"生成详细大纲'
                                        : controller.detailedOutline.value,
                                    style: TextStyle(
                                      color: controller.detailedOutline.value.isEmpty
                                          ? Colors.grey
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (controller.isGenerating.value)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black12,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  Obx(() => ElevatedButton(
                    onPressed: controller.isGenerating.value
                        ? null
                        : controller.confirmAndGenerate,
                    child: const Text('确定'),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 