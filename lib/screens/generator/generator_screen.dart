import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';

class GeneratorScreen extends StatelessWidget {
  final novelController = Get.find<NovelController>();
  final _titleController = TextEditingController();
  final _promptController = TextEditingController();
  final _selectedLength = '中篇'.obs;
  final _selectedStyle = '硬科幻'.obs;

  GeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创作新作品'),
      ),
      body: Obx(() {
        if (novelController.isGenerating.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: novelController.generationProgress.value,
                ),
                const SizedBox(height: 16),
                Text(
                  novelController.generationStatus.value,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  '${(novelController.generationProgress.value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '作品标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: '创作提示',
                border: OutlineInputBorder(),
                helperText: '描述你想要创作的故事情节、背景、人物等',
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '作品设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('作品长度'),
                    Wrap(
                      spacing: 8,
                      children: ['短篇', '中篇', '长篇'].map((length) {
                        return ChoiceChip(
                          label: Text(length),
                          selected: _selectedLength.value == length,
                          onSelected: (selected) {
                            if (selected) {
                              _selectedLength.value = length;
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('作品风格'),
                    Wrap(
                      spacing: 8,
                      children: ['硬科幻', '软科幻', '赛博朋克', '太空歌剧'].map((style) {
                        return ChoiceChip(
                          label: Text(style),
                          selected: _selectedStyle.value == style,
                          onSelected: (selected) {
                            if (selected) {
                              _selectedStyle.value = style;
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_titleController.text.isEmpty) {
                  Get.snackbar('错误', '请输入作品标题');
                  return;
                }
                if (_promptController.text.isEmpty) {
                  Get.snackbar('错误', '请输入创作提示');
                  return;
                }
                novelController.generateNovel(
                  title: _titleController.text,
                  prompt: _promptController.text,
                  length: _selectedLength.value,
                  style: _selectedStyle.value,
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '开始创作',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}