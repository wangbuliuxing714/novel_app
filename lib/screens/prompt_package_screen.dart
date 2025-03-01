import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/models/prompt_package.dart';
import 'package:novel_app/screens/prompt_package_detail_screen.dart';

class PromptPackageScreen extends StatelessWidget {
  const PromptPackageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PromptPackageController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('提示词包管理'),
      ),
      body: Obx(() {
        final packages = controller.promptPackages;
        
        if (packages.isEmpty) {
          return const Center(
            child: Text('还没有提示词包，点击右下角按钮创建一个'),
          );
        }
        
        return ListView.builder(
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final package = packages[index];
            return _buildPromptPackageCard(context, package);
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPromptPackageDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildPromptPackageCard(BuildContext context, PromptPackage package) {
    final controller = Get.find<PromptPackageController>();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => Get.to(() => PromptPackageDetailScreen(packageId: package.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      package.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (package.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '默认',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                package.description,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(_getTypeDisplayName(package.type)),
                    backgroundColor: _getTypeColor(package.type),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (!package.isDefault)
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('设为默认'),
                      onPressed: () => controller.setDefaultPromptPackage(package.id),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteConfirmDialog(context, package),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getTypeDisplayName(String type) {
    final typeNames = {
      'master': '主提示词',
      'outline': '大纲提示词',
      'chapter': '章节提示词',
      'target_reader': '目标读者提示词',
      'expectation': '期待感提示词',
      'character': '角色提示词',
    };
    
    return typeNames[type] ?? type;
  }
  
  Color _getTypeColor(String type) {
    final typeColors = {
      'master': Colors.blue[700],
      'outline': Colors.purple[700],
      'chapter': Colors.orange[700],
      'target_reader': Colors.pink[700],
      'expectation': Colors.teal[700],
      'character': Colors.indigo[700],
    };
    
    return typeColors[type] ?? Colors.grey[700]!;
  }
  
  void _showAddPromptPackageDialog(BuildContext context) {
    final controller = Get.find<PromptPackageController>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final contentController = TextEditingController();
    String selectedType = 'master';
    bool isDefault = false;
    
    final typeOptions = [
      'master',
      'outline',
      'chapter',
      'target_reader',
      'expectation',
      'character',
    ];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建提示词包'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '例如：期待感提示词包',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    hintText: '简要描述这个提示词包的用途',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    border: OutlineInputBorder(),
                  ),
                  items: typeOptions.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(_getTypeDisplayName(type)),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedType = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isDefault,
                      onChanged: (value) => setState(() => isDefault = value ?? false),
                    ),
                    const Text('设为默认'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '提示词内容',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '输入提示词内容...',
                  ),
                  maxLines: 15,
                  minLines: 10,
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
                if (nameController.text.isEmpty || descriptionController.text.isEmpty) {
                  Get.snackbar('错误', '请填写所有必填字段');
                  return;
                }
                
                controller.createPromptPackage(
                  name: nameController.text,
                  description: descriptionController.text,
                  type: selectedType,
                  content: contentController.text,
                  isDefault: isDefault,
                );
                
                Navigator.of(context).pop();
                Get.snackbar('成功', '提示词包创建成功');
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmDialog(BuildContext context, PromptPackage package) {
    final controller = Get.find<PromptPackageController>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除提示词包"${package.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.deletePromptPackage(package.id);
              Navigator.of(context).pop();
              Get.snackbar('成功', '提示词包已删除');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 