import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';

class GeneratorScreen extends StatelessWidget {
  const GeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NovelController());
    final titleController = TextEditingController();
    final promptController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('创作新故事'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '故事设定',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '故事标题',
                        hintText: '请输入故事标题',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: promptController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '故事描述',
                        hintText: '请描述您想要的故事情节、风格等',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: '中篇',
                      decoration: const InputDecoration(
                        labelText: '故事长度',
                      ),
                      items: const [
                        DropdownMenuItem(value: '短篇', child: Text('短篇 (~3000字)')),
                        DropdownMenuItem(value: '中篇', child: Text('中篇 (~8000字)')),
                        DropdownMenuItem(value: '长篇', child: Text('长篇 (~15000字)')),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: '硬科幻',
                      decoration: const InputDecoration(
                        labelText: '故事风格',
                      ),
                      items: const [
                        DropdownMenuItem(value: '硬科幻', child: Text('硬科幻')),
                        DropdownMenuItem(value: '软科幻', child: Text('软科幻')),
                        DropdownMenuItem(value: '赛博朋克', child: Text('赛博朋克')),
                        DropdownMenuItem(value: '太空歌剧', child: Text('太空歌剧')),
                      ],
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => controller.isGenerating.value
                ? Column(
                    children: [
                      LinearProgressIndicator(
                        value: controller.generationProgress.value,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.generationStatus.value,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  )
                : ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isEmpty) {
                        Get.snackbar('错误', '请输入故事标题');
                        return;
                      }
                      if (promptController.text.isEmpty) {
                        Get.snackbar('错误', '请输入故事描述');
                        return;
                      }
                      controller.generateNovel(
                        title: titleController.text,
                        prompt: promptController.text,
                        length: '中篇',
                        style: '硬科幻',
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('开始创作'),
                    ),
                  )),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '创作提示',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 故事描述越详细，生成的内容越符合预期\n'
                      '2. 可以描述故事背景、主要人物、核心冲突等\n'
                      '3. 选择合适的故事长度和风格\n'
                      '4. 生成过程可能需要几分钟，请耐心等待',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 