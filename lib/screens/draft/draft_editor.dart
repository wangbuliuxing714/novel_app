import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/draft_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/models/draft.dart';

class DraftEditor extends StatefulWidget {
  final Draft draft;

  const DraftEditor({super.key, required this.draft});

  @override
  State<DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<DraftEditor> with SingleTickerProviderStateMixin {
  final DraftController _draftController = Get.find();
  final ThemeController _themeController = Get.find();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Timer? _autoSaveTimer;
  bool _hasChanges = false;
  final FocusNode _contentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _contentController = TextEditingController(text: widget.draft.content);

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _hasChanges = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveChanges);
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    await _draftController.updateDraft(
      _titleController.text,
      _contentController.text,
    );
    _hasChanges = false;
  }

  void _showAIModifyDialog() {
    final promptController = TextEditingController();
    final selectedText = _getSelectedText();
    
    if (selectedText.isEmpty) {
      Get.snackbar(
        '提示', 
        '请先选择要修改的文本',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        borderRadius: 8,
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
        animationDuration: const Duration(milliseconds: 300),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'AI修改文本',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选中的文本：',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.2,
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  selectedText,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ),
            TextField(
              controller: promptController,
              decoration: InputDecoration(
                labelText: '修改要求',
                hintText: '例如：改写成更文学性的表达',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final prompt = promptController.text.trim();
              if (prompt.isEmpty) {
                Get.snackbar(
                  '提示', 
                  '请输入修改要求',
                  backgroundColor: Colors.black87,
                  colorText: Colors.white,
                  borderRadius: 8,
                  margin: const EdgeInsets.all(8),
                );
                return;
              }
              
              Navigator.pop(context);
              Get.dialog(
                Center(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                barrierDismissible: false,
              );
              
              final modifiedText = await _draftController.aiModifyText(
                selectedText,
                prompt,
              );
              
              Get.back(); // 关闭加载对话框
              
              if (modifiedText.startsWith('修改失败')) {
                Get.snackbar(
                  '修改失败', 
                  modifiedText,
                  backgroundColor: Colors.red.shade100,
                  colorText: Colors.red.shade900,
                  borderRadius: 8,
                  margin: const EdgeInsets.all(8),
                );
                return;
              }
              
              _replaceSelectedText(modifiedText);
              
              Get.snackbar(
                '修改成功', 
                '文本已更新',
                backgroundColor: Colors.green.shade100,
                colorText: Colors.green.shade900,
                borderRadius: 8,
                margin: const EdgeInsets.all(8),
                duration: const Duration(seconds: 2),
              );
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('修改'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _getSelectedText() {
    final TextSelection selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return '';
    return _contentController.text.substring(selection.start, selection.end);
  }

  void _replaceSelectedText(String newText) {
    final TextSelection selection = _contentController.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _contentController.text;
    final newContent = text.replaceRange(selection.start, selection.end, newText);
    
    _contentController.value = TextEditingValue(
      text: newContent,
      selection: TextSelection.collapsed(
        offset: selection.start + newText.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _themeController.getAdjustedBackgroundColor(),
      ),
      child: Scaffold(
        appBar: isTablet ? null : AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '输入标题',
              hintStyle: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'AI修改',
              onPressed: _showAIModifyDialog,
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              if (isTablet) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            hintText: '输入标题',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high),
                        tooltip: 'AI修改',
                        onPressed: _showAIModifyDialog,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintText: '输入正文',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(() {
                      if (_hasChanges) {
                        return const Text(
                          '正在保存...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      }
                      final draft = _draftController.selectedDraft;
                      if (draft == null) return const SizedBox();
                      return Text(
                        '最后编辑：${_formatDate(draft.updatedAt)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    }),
                    Text(
                      '${_contentController.text.length} 字',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
} 