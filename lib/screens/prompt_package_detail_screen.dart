import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/models/prompt_package.dart';

class PromptPackageDetailScreen extends StatefulWidget {
  final String packageId;
  
  const PromptPackageDetailScreen({
    super.key,
    required this.packageId,
  });

  @override
  State<PromptPackageDetailScreen> createState() => _PromptPackageDetailScreenState();
}

class _PromptPackageDetailScreenState extends State<PromptPackageDetailScreen> {
  final _controller = Get.find<PromptPackageController>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _contentController;
  late bool _isDefault;
  late bool _isEditing;
  PromptPackage? _package;
  
  @override
  void initState() {
    super.initState();
    _loadPackage();
    _isEditing = false;
  }
  
  void _loadPackage() {
    _package = _controller.getPromptPackage(widget.packageId);
    if (_package == null) {
      Get.back();
      Get.snackbar('错误', '找不到提示词包');
      return;
    }
    
    _nameController = TextEditingController(text: _package!.name);
    _descriptionController = TextEditingController(text: _package!.description);
    _contentController = TextEditingController(text: _package!.content);
    _isDefault = _package!.isDefault;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_package == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑提示词包' : '提示词包详情'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildContentSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '基本信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value ?? false),
                  ),
                  const Text('设为默认'),
                ],
              ),
            ] else ...[
              ListTile(
                title: const Text('名称'),
                subtitle: Text(_package!.name),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                title: const Text('描述'),
                subtitle: Text(_package!.description),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                title: const Text('类型'),
                subtitle: Text(_getTypeDisplayName(_package!.type)),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                title: const Text('默认'),
                subtitle: Text(_package!.isDefault ? '是' : '否'),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                title: const Text('创建时间'),
                subtitle: Text(_formatDateTime(_package!.createdAt)),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildContentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '提示词内容',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制内容',
                    onPressed: () => _copyContent(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入提示词内容...',
                ),
                maxLines: 20,
                minLines: 15,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _package!.content,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.grey[800],
                  ),
                ),
              ),
          ],
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
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _package!.content));
    Get.snackbar('成功', '内容已复制到剪贴板');
  }
  
  void _saveChanges() {
    if (_nameController.text.isEmpty || _descriptionController.text.isEmpty) {
      Get.snackbar('错误', '请填写所有必填字段');
      return;
    }
    
    _controller.updatePromptPackage(
      id: _package!.id,
      name: _nameController.text,
      description: _descriptionController.text,
      content: _contentController.text,
      isDefault: _isDefault,
    );
    
    setState(() {
      _isEditing = false;
      _loadPackage(); // 重新加载更新后的数据
    });
    
    Get.snackbar('成功', '提示词包已更新');
  }
} 