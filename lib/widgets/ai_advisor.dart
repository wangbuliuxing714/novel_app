import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/ai_advisor_controller.dart';

class AIAdvisor extends StatelessWidget {
  const AIAdvisor({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AIAdvisorController>();

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
              const Text('AI参谋', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              // 刷新按钮
              Obx(() => IconButton(
                icon: controller.isAnalyzing.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
                onPressed: controller.isAnalyzing.value
                  ? null
                  : controller.analyzeContent,
                tooltip: '重新分析',
              )),
            ],
          ),
        ),
        
        // AI功能区
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              _buildFeatureCard(
                title: '情节推演',
                icon: Icons.timeline,
                onTap: () => controller.getSpecificAdvice('情节推演'),
                controller: controller,
              ),
              _buildFeatureCard(
                title: '人物塑造',
                icon: Icons.person,
                onTap: () => controller.getSpecificAdvice('人物塑造'),
                controller: controller,
              ),
              _buildFeatureCard(
                title: '场景描写',
                icon: Icons.landscape,
                onTap: () => controller.getSpecificAdvice('场景描写'),
                controller: controller,
              ),
              _buildFeatureCard(
                title: '对话优化',
                icon: Icons.chat_bubble,
                onTap: () => controller.getSpecificAdvice('对话优化'),
                controller: controller,
              ),
              _buildFeatureCard(
                title: '文风调整',
                icon: Icons.style,
                onTap: () => controller.getSpecificAdvice('文风调整'),
                controller: controller,
              ),
              
              const Divider(),
              
              // AI建议区
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AI建议',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Obx(() {
                          if (controller.isAnalyzing.value) {
                            return const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return const SizedBox();
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      if (controller.suggestions.isEmpty) {
                        return Text(
                          controller.isAnalyzing.value ? '正在分析...' : '暂无建议',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: controller.suggestions.map((suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(
                                child: Text(suggestion),
                              ),
                            ],
                          ),
                        )).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 底部输入区
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
              Expanded(
                child: TextField(
                  controller: controller.questionController,
                  decoration: const InputDecoration(
                    hintText: '向AI提问...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 1,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      controller.handleCustomQuestion(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  final question = controller.questionController.text;
                  if (question.isNotEmpty) {
                    controller.handleCustomQuestion(question);
                  }
                },
                tooltip: '发送',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required AIAdvisorController controller,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Obx(() {
          if (controller.isAnalyzing.value) {
            return const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return const Icon(Icons.arrow_forward_ios, size: 16);
        }),
        onTap: controller.isAnalyzing.value ? null : onTap,
      ),
    );
  }
} 