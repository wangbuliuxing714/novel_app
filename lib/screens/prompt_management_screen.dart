import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/prompt_template.dart';

class PromptManagementScreen extends StatelessWidget {
  const PromptManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final promptManager = Get.find<PromptManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('提示词管理'),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '系统提示词'),
                Tab(text: '类型提示词'),
                Tab(text: '情节提示词'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPromptList(promptManager.systemPrompts, '系统'),
                  _buildPromptList(promptManager.genrePrompts, '类型'),
                  _buildPromptList(promptManager.plotPrompts, '情节'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPromptDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPromptList(RxList<PromptTemplate> prompts, String category) {
    return Obx(
      () => ListView.builder(
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(prompt.name),
              subtitle: Text(prompt.description),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditPromptDialog(context, prompt),
              ),
              onTap: () => _showPromptDetails(context, prompt),
            ),
          );
        },
      ),
    );
  }

  void _showPromptDetails(BuildContext context, PromptTemplate prompt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prompt.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('描述：${prompt.description}'),
              const SizedBox(height: 16),
              const Text('模板内容：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(prompt.template),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showEditPromptDialog(BuildContext context, PromptTemplate prompt) {
    final nameController = TextEditingController(text: prompt.name);
    final descriptionController = TextEditingController(text: prompt.description);
    final templateController = TextEditingController(text: prompt.template);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑提示词'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              TextField(
                controller: templateController,
                decoration: const InputDecoration(labelText: '模板内容'),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newPrompt = PromptTemplate(
                id: prompt.id,
                name: nameController.text,
                description: descriptionController.text,
                template: templateController.text,
                category: prompt.category,
              );
              Get.find<PromptManager>().updatePrompt(newPrompt);
              Navigator.of(context).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddPromptDialog(BuildContext context) {
    // TODO: 实现添加新提示词的功能
  }
} 