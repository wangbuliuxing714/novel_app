import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/screens/generator/novel_settings_screen.dart';

class GeneratorScreen extends StatelessWidget {
  const GeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NovelController());
    final titleController = TextEditingController(text: controller.currentNovelTitle);

    return Scaffold(
      appBar: AppBar(
        title: const Text('创作新故事'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.to(() => const NovelSettingsScreen()),
            tooltip: '高级设置',
          ),
        ],
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
                      '基本设置',
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
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => controller.setNovelTitle(value),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.settings_applications),
                            label: const Text('高级设置'),
                            onPressed: () => Get.to(() => const NovelSettingsScreen()),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => controller.isGenerating.value
                ? _buildGenerationProgressWidget(controller, context)
                : _buildGenerationControlWidget(controller, titleController)),
            const SizedBox(height: 16),
            _buildGenerationOutputWidget(controller),
            const SizedBox(height: 16),
            _buildTipsWidget(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenerationProgressWidget(NovelController controller, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(() => controller.isPaused.value
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('继续生成'),
                        onPressed: controller.resumeGeneration,
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.pause),
                        label: const Text('暂停生成'),
                        onPressed: controller.pauseGeneration,
                      )),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('停止生成'),
                  onPressed: controller.stopGeneration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenerationControlWidget(NovelController controller, TextEditingController titleController) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '生成控制',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始新小说'),
                    onPressed: () {
                      if (titleController.text.isEmpty) {
                        Get.snackbar('错误', '请输入故事标题');
                        return;
                      }
                      
                      controller.generateNovel(
                        title: titleController.text,
                        genre: controller.selectedGenres.join('、'),
                        theme: controller.currentNovelBackground,
                        totalChapters: controller.totalChapters,
                        background: controller.currentNovelBackground,
                        style: controller.selectedStyle,
                        specialRequirements: controller.specialRequirements,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('继续生成'),
                    onPressed: () {
                      if (titleController.text.isEmpty) {
                        Get.snackbar('错误', '请输入故事标题');
                        return;
                      }
                      
                      controller.generateNovel(
                        title: titleController.text,
                        genre: controller.selectedGenres.join('、'),
                        theme: controller.currentNovelBackground,
                        totalChapters: controller.totalChapters,
                        background: controller.currentNovelBackground,
                        style: controller.selectedStyle,
                        specialRequirements: controller.specialRequirements,
                        continueGeneration: true,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenerationOutputWidget(NovelController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '生成输出',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.all(16),
              child: Obx(() => SingleChildScrollView(
                child: Text(
                  controller.realtimeOutput.value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTipsWidget() {
    return const Card(
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
              '1. 在高级设置中可以设置更多参数，如角色、背景、风格等\n'
              '2. 生成过程中可以随时暂停和继续\n'
              '3. 生成完成后可以在小说库中查看和编辑\n'
              '4. 可以使用角色卡片和角色类型来丰富故事角色',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 