import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/models/prompt_package.dart';
import 'package:novel_app/screens/prompt_package/prompt_package_detail_screen.dart';

class PromptPackageScreen extends StatelessWidget {
  const PromptPackageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PromptPackageController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('提示词包管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPromptPackageDialog(context),
          ),
        ],
      ),
      body: Obx(() {
        final packages = controller.promptPackages;
        
        if (packages.isEmpty) {
          return const Center(
            child: Text('还没有创建任何提示词包'),
          );
        }
        
        return ListView.builder(
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final package = packages[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Row(
                  children: [
                    Text(package.name),
                    if (package.isDefault)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
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
                subtitle: Text(
                  package.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!package.isDefault)
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: '设为默认',
                        onPressed: () => controller.setDefaultPromptPackage(package.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: '编辑',
                      onPressed: () => Get.to(() => PromptPackageDetailScreen(packageId: package.id)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: '删除',
                      onPressed: () => _showDeleteConfirmDialog(context, package),
                    ),
                  ],
                ),
                onTap: () => Get.to(() => PromptPackageDetailScreen(packageId: package.id)),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPromptPackageDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  void _showAddPromptPackageDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final typeController = TextEditingController(text: 'master');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建提示词包'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：期待感提示词包',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '简要描述这个提示词包的用途',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                labelText: '类型',
                hintText: '例如：master, outline, chapter',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty || descriptionController.text.isEmpty || typeController.text.isEmpty) {
                Get.snackbar('错误', '请填写所有字段');
                return;
              }
              
              Get.find<PromptPackageController>().createPromptPackage(
                name: nameController.text,
                description: descriptionController.text,
                type: typeController.text,
                content: '',
              );
              
              Navigator.pop(context);
              Get.snackbar('成功', '提示词包创建成功');
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmDialog(BuildContext context, PromptPackage package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除提示词包"${package.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.find<PromptPackageController>().deletePromptPackage(package.id);
              Navigator.pop(context);
              Get.snackbar('成功', '提示词包已删除');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}