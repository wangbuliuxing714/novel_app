import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/genre_category.dart';
import 'package:novel_app/controllers/genre_controller.dart';

class GenreManagerScreen extends StatelessWidget {
  final genreController = Get.find<GenreController>();

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
      body: Obx(() => ListView.builder(
        itemCount: genreController.categories.length,
        itemBuilder: (context, index) {
          final category = genreController.categories[index];
          return _buildCategoryCard(context, category, index);
        },
      )),
    );
  }

  Widget _buildCategoryCard(BuildContext context, GenreCategory category, int categoryIndex) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(category.name)),
            if (!genreController.isDefaultCategory(category.name))
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => genreController.deleteCategory(categoryIndex),
              ),
          ],
        ),
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: category.genres.length,
            itemBuilder: (context, index) {
              final genre = category.genres[index];
              return ListTile(
                title: Text(genre.name),
                subtitle: Text(genre.description),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditGenreDialog(context, genre, categoryIndex, index),
                    ),
                    if (!genreController.isDefaultGenre(category.name, genre.name))
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => genreController.deleteGenre(categoryIndex, index),
                      ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加类型'),
              onPressed: () => _showAddGenreDialog(context, categoryIndex),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新分类'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '分类名称',
            hintText: '请输入分类名称',
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
                genreController.addCategory(GenreCategory(
                  name: nameController.text,
                  genres: [],
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

  void _showAddGenreDialog(BuildContext context, int categoryIndex) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新类型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '类型名称',
                  hintText: '请输入类型名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '类型描述',
                  hintText: '请输入类型描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                decoration: const InputDecoration(
                  labelText: '提示词',
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
                genreController.addGenre(
                  categoryIndex,
                  NovelGenre(
                    name: nameController.text,
                    description: descriptionController.text,
                    prompt: promptController.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditGenreDialog(BuildContext context, NovelGenre genre, int categoryIndex, int genreIndex) {
    final nameController = TextEditingController(text: genre.name);
    final descriptionController = TextEditingController(text: genre.description);
    final promptController = TextEditingController(text: genre.prompt);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑类型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '类型名称',
                  hintText: '请输入类型名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '类型描述',
                  hintText: '请输入类型描述',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                decoration: const InputDecoration(
                  labelText: '提示词',
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
                genreController.updateGenre(
                  categoryIndex,
                  genreIndex,
                  NovelGenre(
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