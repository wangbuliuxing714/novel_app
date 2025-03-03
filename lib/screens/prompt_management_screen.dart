import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/models/prompt_package.dart';

class PromptManagementScreen extends StatefulWidget {
  const PromptManagementScreen({super.key});

  @override
  State<PromptManagementScreen> createState() => _PromptManagementScreenState();
}

class _PromptManagementScreenState extends State<PromptManagementScreen> with SingleTickerProviderStateMixin {
  final _controller = Get.find<PromptPackageController>();
  late TabController _tabController;
  
  final List<String> _promptTypes = [
    'master',
    'outline',
    'chapter',
    'target_reader',
    'expectation',
    'character',
    'short_novel',
  ];
  
  final Map<String, String> _promptTypeNames = {
    'master': '主提示词',
    'outline': '大纲提示词',
    'chapter': '章节提示词',
    'target_reader': '目标读者提示词',
    'expectation': '期待感提示词',
    'character': '角色提示词',
    'short_novel': '短篇小说提示词',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _promptTypes.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('提示词管理'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _promptTypes.map((type) => Tab(text: _promptTypeNames[type] ?? type)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _promptTypes.map((type) => _buildPromptList(type)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPromptDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPromptList(String type) {
    return Obx(() {
      final packages = _controller.getPromptPackagesByType(type);
      
      if (packages.isEmpty) {
        return Center(
          child: Text('还没有${_promptTypeNames[type] ?? type}提示词包'),
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
                      onPressed: () => _controller.setDefaultPromptPackage(package.id),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: '编辑',
                    onPressed: () => _showEditPromptDialog(context, package),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '删除',
                    onPressed: () => _showDeleteConfirmDialog(context, package),
                  ),
                ],
              ),
              onTap: () => _showPromptDetails(context, package),
            ),
          );
        },
      );
    });
  }

  void _showPromptDetails(BuildContext context, PromptPackage package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(package.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('描述：${package.description}'),
              const SizedBox(height: 16),
              const Text('提示词内容：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(package.content),
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

  void _showEditPromptDialog(BuildContext context, PromptPackage package) {
    final nameController = TextEditingController(text: package.name);
    final descriptionController = TextEditingController(text: package.description);
    final contentController = TextEditingController(text: package.content);
    bool isDefault = package.isDefault;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑提示词包'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                
                _controller.updatePromptPackage(
                  id: package.id,
                  name: nameController.text,
                  description: descriptionController.text,
                  content: contentController.text,
                  isDefault: isDefault,
                );
                
                Navigator.of(context).pop();
                Get.snackbar('成功', '提示词包已更新');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPromptDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final contentController = TextEditingController();
    String selectedType = _promptTypes.first;
    bool isDefault = false;

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
                  items: _promptTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(_promptTypeNames[type] ?? type),
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
                
                _controller.createPromptPackage(
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
              _controller.deletePromptPackage(package.id);
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