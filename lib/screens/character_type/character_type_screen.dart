import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:uuid/uuid.dart';

class CharacterTypeScreen extends StatelessWidget {
  final CharacterTypeService _characterTypeService = Get.find<CharacterTypeService>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedColor = const Color(0xFF2196F3).obs;

  CharacterTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色类型管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context),
          ),
        ],
      ),
      body: Obx(
        () => ListView.builder(
          itemCount: _characterTypeService.characterTypes.length,
          itemBuilder: (context, index) {
            final type = _characterTypeService.characterTypes[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(int.parse(type.color, radix: 16)),
              ),
              title: Text(type.name),
              subtitle: Text(type.description),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showAddEditDialog(context, type),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteDialog(context, type),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, [CharacterType? type]) {
    if (type != null) {
      _nameController.text = type.name;
      _descriptionController.text = type.description;
      _selectedColor.value = Color(int.parse(type.color, radix: 16));
    } else {
      _nameController.clear();
      _descriptionController.clear();
      _selectedColor.value = const Color(0xFF2196F3);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == null ? '添加角色类型' : '编辑角色类型'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '类型名称'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入类型名称';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '类型描述'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入类型描述';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('选择颜色：'),
                  Obx(() => IconButton(
                    icon: Icon(Icons.circle, color: _selectedColor.value),
                    onPressed: () => _showColorPicker(context),
                  )),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newType = CharacterType(
                  id: type?.id ?? const Uuid().v4(),
                  name: _nameController.text,
                  description: _descriptionController.text,
                  color: _selectedColor.value.value.toRadixString(16),
                );

                if (type == null) {
                  _characterTypeService.addCharacterType(newType);
                } else {
                  _characterTypeService.updateCharacterType(newType);
                }

                Get.back();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Color(0xFFF44336), // Red
              const Color(0xFFE91E63), // Pink
              const Color(0xFF9C27B0), // Purple
              const Color(0xFF673AB7), // Deep Purple
              const Color(0xFF3F51B5), // Indigo
              const Color(0xFF2196F3), // Blue
              const Color(0xFF03A9F4), // Light Blue
              const Color(0xFF00BCD4), // Cyan
              const Color(0xFF009688), // Teal
              const Color(0xFF4CAF50), // Green
              const Color(0xFF8BC34A), // Light Green
              const Color(0xFFCDDC39), // Lime
              const Color(0xFFFFEB3B), // Yellow
              const Color(0xFFFFC107), // Amber
              const Color(0xFFFF9800), // Orange
              const Color(0xFFFF5722), // Deep Orange
              const Color(0xFF795548), // Brown
              const Color(0xFF9E9E9E), // Grey
              const Color(0xFF607D8B), // Blue Grey
            ].map((color) => InkWell(
              onTap: () {
                _selectedColor.value = color;
                Get.back();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CharacterType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色类型'),
        content: Text('确定要删除角色类型"${type.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _characterTypeService.deleteCharacterType(type.id);
              Get.back();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 