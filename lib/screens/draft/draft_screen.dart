import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/draft_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/models/draft.dart';
import 'package:novel_app/screens/draft/draft_editor.dart';

class DraftScreen extends StatelessWidget {
  final DraftController _draftController = Get.find();
  final ThemeController _themeController = Get.find();

  DraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('草稿本', style: TextStyle(fontWeight: FontWeight.w500)),
        elevation: 0,
        centerTitle: true,
        actions: [
          Hero(
            tag: 'add_draft_button',
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreateDraftDialog(context),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 草稿内容
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return Obx(() {
      final drafts = _draftController.drafts;
      final selectedDraft = _draftController.selectedDraft;
      
      if (selectedDraft != null) {
        return Hero(
          tag: 'draft_${selectedDraft.id}',
          child: WillPopScope(
            onWillPop: () async {
              _draftController.selectDraft(null);
              return false;
            },
            child: DraftEditor(draft: selectedDraft),
          ),
        );
      }
      
      if (drafts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '暂无草稿',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateDraftDialog(Get.context!),
                icon: const Icon(Icons.add),
                label: const Text('新建草稿'),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: drafts.length,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return Hero(
            tag: 'draft_${draft.id}',
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _draftController.selectDraft(draft),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  draft.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showDeleteDraftDialog(context, draft),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            draft.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '最后编辑：${_formatDate(draft.updatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Obx(() {
            final drafts = _draftController.drafts;
            if (drafts.isEmpty) {
              return const Center(
                child: Text(
                  '暂无草稿',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: drafts.length,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final draft = drafts[index];
                return Obx(() {
                  final isSelected = draft.id == _draftController.selectedDraft?.id;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: Text(
                        draft.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '最后编辑：${_formatDate(draft.updatedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      selected: isSelected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () => _draftController.selectDraft(draft),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _showDeleteDraftDialog(context, draft),
                      ),
                    ),
                  );
                });
              },
            );
          }),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Obx(() {
            final selectedDraft = _draftController.selectedDraft;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: selectedDraft == null
                  ? const Center(
                      child: Text(
                        '请选择或创建草稿',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : DraftEditor(draft: selectedDraft),
            );
          }),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showCreateDraftDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建草稿'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '标题',
            hintText: '请输入草稿标题',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                _draftController.createDraft(title);
                Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDraftDialog(BuildContext context, Draft draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除草稿'),
        content: Text('确定要删除草稿"${draft.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _draftController.deleteDraft(draft.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
} 