import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:uuid/uuid.dart';

class GenreManagerScreen extends StatelessWidget {
  final _genreController = Get.find<GenreController>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _promptController = TextEditingController();

  GenreManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('类型管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
      ),
      body: Obx(
        () => ListView.builder(
          itemCount: _genreController.categories.length,
          itemBuilder: (context, index) {
            final category = _genreController.categories[index];
            return _buildCategoryCard(context, category, index);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, GenreCategory category, int index) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              category.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: _genreController.isDefaultCategory(category.name)
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddGenreDialog(context, index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _showDeleteCategoryDialog(context, index),
                      ),
                    ],
                  ),
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.genres.asMap().entries.map((entry) {
              final genreIndex = entry.key;
              final genre = entry.value;
              return Chip(
                label: Text(genre.name),
                onDeleted: _genreController.isDefaultGenre(category.name, genre.name)
                    ? null
                    : () => _showDeleteGenreDialog(context, index, genreIndex),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    _nameController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新分类'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '分类名称',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入分类名称';
              }
              return null;
            },
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
                final category = GenreCategory(
                  name: _nameController.text,
                  genres: [],
                );
                _genreController.addCategory(category);
                Get.back();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showAddGenreDialog(BuildContext context, int categoryIndex) {
    _nameController.clear();
    _descriptionController.clear();
    _promptController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新类型'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '类型名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入类型名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '类型描述',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入类型描述';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _promptController,
                decoration: const InputDecoration(
                  labelText: '提示词',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入提示词';
                  }
                  return null;
                },
                maxLines: 3,
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
                final genre = NovelGenre(
                  name: _nameController.text,
                  description: _descriptionController.text,
                  prompt: _promptController.text,
                );
                _genreController.addGenre(categoryIndex, genre);
                Get.back();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: const Text('确定要删除这个分类吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _genreController.deleteCategory(index);
              Get.back();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGenreDialog(BuildContext context, int categoryIndex, int genreIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除类型'),
        content: const Text('确定要删除这个类型吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _genreController.deleteGenre(categoryIndex, genreIndex);
              Get.back();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 