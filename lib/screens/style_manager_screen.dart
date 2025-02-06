import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/style_controller.dart';

class StyleManagerScreen extends StatelessWidget {
  final styleController = Get.find<StyleController>();

  StyleManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('写作风格管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddStyleDialog(context),
          ),
        ],
      ),
      body: Obx(() => ListView.builder(
        itemCount: styleController.styles.length,
        itemBuilder: (context, index) {
          final style = styleController.styles[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(style.name),
              subtitle: Text(style.description),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditStyleDialog(context, style, index),
                  ),
                  if (!styleController.isDefaultStyle(style.name))
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => styleController.deleteStyle(index),
                    ),
                ],
              ),
            ),
          );
        },
      )),
    );
  }

  void _showAddStyleDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新风格'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '风格名称',
                  hintText: '请输入风格名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '风格描述',
                  hintText: '请输入风格描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                decoration: const InputDecoration(
                  labelText: 'AI提示词',
                  hintText: '请输入AI生成提示词',
                ),
                maxLines: 3,
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                styleController.addStyle(WritingStyle(
                  name: nameController.text,
                  description: descriptionController.text,
                  prompt: promptController.text,
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditStyleDialog(BuildContext context, WritingStyle style, int index) {
    final nameController = TextEditingController(text: style.name);
    final descriptionController = TextEditingController(text: style.description);
    final promptController = TextEditingController(text: style.prompt);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑风格'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '风格名称',
                  hintText: '请输入风格名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '风格描述',
                  hintText: '请输入风格描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                decoration: const InputDecoration(
                  labelText: 'AI提示词',
                  hintText: '请输入AI生成提示词',
                ),
                maxLines: 3,
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                styleController.updateStyle(
                  index,
                  WritingStyle(
                    name: nameController.text,
                    description: descriptionController.text,
                    prompt: promptController.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
} 