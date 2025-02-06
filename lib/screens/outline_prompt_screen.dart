import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/outline_prompt_controller.dart';

class OutlinePromptScreen extends StatelessWidget {
  final outlineController = Get.find<OutlinePromptController>();

  OutlinePromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大纲提示词管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPromptDialog(context),
          ),
        ],
      ),
      body: Obx(() => ListView.builder(
        itemCount: outlineController.prompts.length,
        itemBuilder: (context, index) {
          final prompt = outlineController.prompts[index];
          final isDefault = outlineController.isDefaultPrompt(prompt.name);
          final isSelected = outlineController.selectedPrompt.value?.name == prompt.name;
          
          return Card(
            margin: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Radio<String>(
                    value: prompt.name,
                    groupValue: outlineController.selectedPrompt.value?.name,
                    onChanged: (value) async {
                      if (value != null) {
                        await outlineController.setSelectedPrompt(value);
                        Get.snackbar(
                          '已选择',
                          '已将"${prompt.name}"设为默认大纲模板',
                          backgroundColor: Colors.green.withOpacity(0.1),
                        );
                      }
                    },
                  ),
                  title: Row(
                    children: [
                      Text(prompt.name),
                      if (isDefault)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '当前使用',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(prompt.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showViewPromptDialog(context, prompt),
                      ),
                      if (!isDefault) ...[
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditPromptDialog(context, prompt, index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _showDeleteConfirmDialog(context, index),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      )),
    );
  }

  void _showViewPromptDialog(BuildContext context, OutlinePrompt prompt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('查看提示词模板'),
            if (outlineController.isDefaultPrompt(prompt.name))
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '默认',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('名称：${prompt.name}'),
              const SizedBox(height: 8),
              Text('描述：${prompt.description}'),
              const SizedBox(height: 16),
              const Text('模板内容：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(prompt.template),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个提示词模板吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await outlineController.deletePrompt(index);
                Navigator.pop(context);
                Get.snackbar(
                  '成功',
                  '提示词模板已删除',
                  backgroundColor: Colors.green.withOpacity(0.1),
                );
              } catch (e) {
                Get.snackbar(
                  '错误',
                  '删除失败：$e',
                  backgroundColor: Colors.red.withOpacity(0.1),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddPromptDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final templateController = TextEditingController(
      text: outlineController.baseTemplateStructure,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新提示词模板'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '模板名称',
                  hintText: '请输入模板名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '模板描述',
                  hintText: '请输入模板描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '变量说明',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(outlineController.variableExplanation),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: templateController,
                decoration: const InputDecoration(
                  labelText: '提示词模板',
                  hintText: '请输入提示词模板内容',
                ),
                maxLines: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await outlineController.addPrompt(OutlinePrompt(
                    name: nameController.text,
                    description: descriptionController.text,
                    template: templateController.text,
                  ));
                  Navigator.pop(context);
                  Get.snackbar(
                    '成功',
                    '提示词模板已保存',
                    backgroundColor: Colors.green.withOpacity(0.1),
                  );
                } catch (e) {
                  Get.snackbar(
                    '错误',
                    '保存失败：$e',
                    backgroundColor: Colors.red.withOpacity(0.1),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditPromptDialog(BuildContext context, OutlinePrompt prompt, int index) {
    final nameController = TextEditingController(text: prompt.name);
    final descriptionController = TextEditingController(text: prompt.description);
    final templateController = TextEditingController(text: prompt.template);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑提示词模板'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '模板名称',
                  hintText: '请输入模板名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '模板描述',
                  hintText: '请输入模板描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '变量说明',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(outlineController.variableExplanation),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: templateController,
                decoration: const InputDecoration(
                  labelText: '提示词模板',
                  hintText: '请输入提示词模板内容',
                ),
                maxLines: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await outlineController.updatePrompt(
                    index,
                    OutlinePrompt(
                      name: nameController.text,
                      description: descriptionController.text,
                      template: templateController.text,
                    ),
                  );
                  Navigator.pop(context);
                  Get.snackbar(
                    '成功',
                    '提示词模板已更新',
                    backgroundColor: Colors.green.withOpacity(0.1),
                  );
                } catch (e) {
                  Get.snackbar(
                    '错误',
                    '更新失败：$e',
                    backgroundColor: Colors.red.withOpacity(0.1),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
} 