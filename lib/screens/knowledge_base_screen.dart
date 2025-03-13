import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/knowledge_base_controller.dart';
import 'package:novel_app/models/knowledge_document.dart';

class KnowledgeBaseScreen extends StatelessWidget {
  final KnowledgeBaseController controller = Get.find<KnowledgeBaseController>();
  
  KnowledgeBaseScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识库管理'),
        actions: [
          // 多选模式切换按钮
          Obx(() => IconButton(
            icon: Icon(controller.isMultiSelectMode.value ? Icons.check_circle : Icons.check_circle_outline),
            tooltip: controller.isMultiSelectMode.value ? '退出多选模式' : '进入多选模式',
            onPressed: () => controller.toggleMultiSelectMode(),
          )),
          // 添加知识按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加知识',
            onPressed: () => _showAddDocumentDialog(context),
          ),
        ],
      ),
      body: Obx(() => Column(
        children: [
          // 分类标签
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ...controller.categories.map((category) {
                  final count = controller.documents
                    .where((doc) => doc.category == category)
                    .length;
                  return ActionChip(
                    label: Text('$category ($count)'),
                    onPressed: () {
                      // 可以添加过滤功能
                    },
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('添加分类'),
                  onPressed: () => _showAddCategoryDialog(context),
                ),
              ],
            ),
          ),
          
          // 多选模式下的操作栏
          if (controller.isMultiSelectMode.value)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Colors.blue.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('已选择 ${controller.selectedDocIds.length} 个文档'),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.select_all),
                        label: const Text('全选'),
                        onPressed: () => controller.selectAllDocuments(),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.deselect),
                        label: const Text('取消全选'),
                        onPressed: () => controller.deselectAllDocuments(),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('清除选择'),
                        onPressed: () => controller.clearSelection(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // 文档列表
          Expanded(
            child: controller.documents.isEmpty
                ? const Center(
                    child: Text('暂无知识文档，请添加'),
                  )
                : ListView.builder(
                    itemCount: controller.documents.length,
                    itemBuilder: (context, index) {
                      final doc = controller.documents[index];
                      return _buildDocumentCard(context, doc);
                    },
                  ),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDocumentDialog(context),
      ),
    );
  }
  
  Widget _buildDocumentCard(BuildContext context, KnowledgeDocument doc) {
    final isSelected = controller.selectedDocIds.contains(doc.id);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: controller.isMultiSelectMode.value
            ? () => controller.toggleDocumentSelection(doc.id)
            : () => _showDocumentDetail(context, doc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(
                doc.title, 
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : null,
                ),
              ),
              subtitle: Text('分类: ${doc.category}  |  更新: ${doc.updatedAt.toString().substring(0, 16)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 选择/取消选择
                  if (controller.isMultiSelectMode.value)
                    Icon(
                      isSelected ? Icons.check_circle : Icons.check_circle_outline,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                  // 编辑和删除按钮
                  if (!controller.isMultiSelectMode.value) ...[
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: '编辑',
                      onPressed: () => _showEditDocumentDialog(context, doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: '删除',
                      onPressed: () => _confirmDeleteDocument(context, doc),
                    ),
                  ],
                ],
              ),
            ),
            
            // 预览前100个字符的内容
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                doc.content.length > 100
                    ? '${doc.content.substring(0, 100)}...'
                    : doc.content,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 显示添加分类对话框
  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController categoryController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分类'),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: '分类名称',
            hintText: '输入新分类名称',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('添加'),
            onPressed: () {
              if (categoryController.text.isNotEmpty) {
                controller.addCategory(categoryController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
  
  // 显示添加文档对话框
  void _showAddDocumentDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final selectedCategory = controller.categories.first.obs;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加知识'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '知识标题',
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => DropdownButtonFormField<String>(
                value: selectedCategory.value,
                decoration: const InputDecoration(
                  labelText: '分类',
                  hintText: '选择分类',
                ),
                items: controller.categories.map((category) => 
                  DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )
                ).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory.value = value;
                  }
                },
              )),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '内容',
                  hintText: '输入知识内容',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('保存'),
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                controller.addDocument(KnowledgeDocument(
                  title: titleController.text,
                  content: contentController.text,
                  category: selectedCategory.value,
                ));
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
  
  // 显示编辑文档对话框
  void _showEditDocumentDialog(BuildContext context, KnowledgeDocument doc) {
    final titleController = TextEditingController(text: doc.title);
    final contentController = TextEditingController(text: doc.content);
    final selectedCategory = doc.category.obs;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑知识'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => DropdownButtonFormField<String>(
                value: selectedCategory.value,
                decoration: const InputDecoration(
                  labelText: '分类',
                ),
                items: controller.categories.map((category) => 
                  DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )
                ).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedCategory.value = value;
                  }
                },
              )),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('保存'),
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                final updatedDoc = KnowledgeDocument(
                  id: doc.id,
                  title: titleController.text,
                  content: contentController.text,
                  category: selectedCategory.value,
                  createdAt: doc.createdAt,
                );
                controller.updateDocument(updatedDoc);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
  
  // 确认删除文档
  void _confirmDeleteDocument(BuildContext context, KnowledgeDocument doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${doc.title}" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('删除', style: TextStyle(color: Colors.red)),
            onPressed: () {
              controller.deleteDocument(doc.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除：${doc.title}')),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // 显示文档详情
  void _showDocumentDetail(BuildContext context, KnowledgeDocument doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('分类: ${doc.category}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text('创建: ${doc.createdAt.toString().substring(0, 16)}'),
              Text('更新: ${doc.updatedAt.toString().substring(0, 16)}'),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              SelectableText(doc.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('关闭'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
} 