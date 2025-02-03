import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:novel_app/controllers/outline_controller.dart';
import 'package:novel_app/services/ai_service.dart';

class EditorController extends GetxController {
  final outlineController = Get.find<OutlineController>();
  final aiService = Get.find<AIService>();
  
  // 编辑器控制器
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  
  // 状态变量
  final isSaving = false.obs;
  final lastSaveTime = ''.obs;
  final wordCount = 0.obs;
  final fontSize = 16.0.obs;
  
  // 撤销/重做历史
  final _undoStack = <String>[].obs;
  final _redoStack = <String>[].obs;
  final canUndo = false.obs;
  final canRedo = false.obs;
  String _lastContent = '';
  Timer? _changeTimer;
  
  // 自动保存定时器
  Timer? _autoSaveTimer;
  
  @override
  void onInit() {
    super.onInit();
    // 监听章节选择变化
    ever(outlineController.selectedChapterId, (_) => _loadChapter());
    
    // 设置自动保存
    _setupAutoSave();
    
    // 监听内容变化以更新字数和历史记录
    contentController.addListener(() {
      _updateWordCount();
      _handleContentChange();
    });
  }
  
  @override
  void onClose() {
    _autoSaveTimer?.cancel();
    _changeTimer?.cancel();
    titleController.dispose();
    contentController.dispose();
    super.onClose();
  }
  
  // 处理内容变化
  void _handleContentChange() {
    _changeTimer?.cancel();
    _changeTimer = Timer(const Duration(milliseconds: 500), () {
      final currentContent = contentController.text;
      if (currentContent != _lastContent) {
        _undoStack.add(_lastContent);
        _redoStack.clear();
        _lastContent = currentContent;
        _updateUndoRedoState();
      }
    });
  }
  
  // 更新撤销/重做状态
  void _updateUndoRedoState() {
    canUndo.value = _undoStack.isNotEmpty;
    canRedo.value = _redoStack.isNotEmpty;
  }
  
  // 撤销
  void undo() {
    if (!canUndo.value) return;
    
    final currentContent = contentController.text;
    _redoStack.add(currentContent);
    
    final previousContent = _undoStack.removeLast();
    _lastContent = previousContent;
    contentController.text = previousContent;
    contentController.selection = TextSelection.collapsed(offset: previousContent.length);
    
    _updateUndoRedoState();
  }
  
  // 重做
  void redo() {
    if (!canRedo.value) return;
    
    final currentContent = contentController.text;
    _undoStack.add(currentContent);
    
    final nextContent = _redoStack.removeLast();
    _lastContent = nextContent;
    contentController.text = nextContent;
    contentController.selection = TextSelection.collapsed(offset: nextContent.length);
    
    _updateUndoRedoState();
  }
  
  // 加载选中的章节
  void _loadChapter() {
    final chapter = outlineController.getSelectedChapter();
    if (chapter != null) {
      titleController.text = chapter.title;
      contentController.text = chapter.content;
      _lastContent = chapter.content;
      _undoStack.clear();
      _redoStack.clear();
      _updateUndoRedoState();
      _updateWordCount();
    } else {
      titleController.clear();
      contentController.clear();
      _lastContent = '';
      _undoStack.clear();
      _redoStack.clear();
      _updateUndoRedoState();
      wordCount.value = 0;
    }
  }
  
  // 设置自动保存（每30秒）
  void _setupAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      saveContent();
    });
  }
  
  // 更新字数统计
  void _updateWordCount() {
    final text = contentController.text;
    wordCount.value = text.replaceAll(RegExp(r'\s'), '').length;
  }
  
  // 保存内容
  Future<void> saveContent() async {
    final chapter = outlineController.getSelectedChapter();
    if (chapter == null) return;
    
    isSaving.value = true;
    
    try {
      // 更新标题和内容
      outlineController.updateChapterTitle(chapter.id, titleController.text);
      outlineController.updateChapterContent(chapter.id, contentController.text);
      
      // 更新保存时间
      final now = DateTime.now();
      lastSaveTime.value = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
    } catch (e) {
      Get.snackbar(
        '保存失败',
        '请检查网络连接后重试',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSaving.value = false;
    }
  }
  
  // 调整字体大小
  void changeFontSize(double delta) {
    fontSize.value = (fontSize.value + delta).clamp(12.0, 32.0);
  }
  
  // 获取编辑器是否有未保存的更改
  bool hasUnsavedChanges() {
    final chapter = outlineController.getSelectedChapter();
    if (chapter == null) return false;
    
    return chapter.title != titleController.text || 
           chapter.content != contentController.text;
  }

  // AI修改对话框
  void showAIEditDialog(
    String selectedText,
    TextSelection selection,
    TextEditingController textController,
  ) {
    final requirementController = TextEditingController();
    final isGenerating = false.obs;
    String? generatedText;
    
    Get.dialog(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AI修改',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // 显示选中的文字
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '选中内容：',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(selectedText),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 修改要求输入框
              TextField(
                controller: requirementController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '修改要求（可选）',
                  hintText: '请输入具体的修改要求，如：使语言更加生动、增加细节描写等',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // 清空之前的生成结果，以便重新生成
                  generatedText = null;
                },
              ),
              const SizedBox(height: 16),
              // 生成结果区域
              Obx(() {
                if (isGenerating.value) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          '正在生成修改内容...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                if (generatedText != null) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '修改结果：',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(generatedText!),
                      ],
                    ),
                  );
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Text(
                    '点击"生成"或"应用修改"按钮开始生成内容',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  // 添加生成按钮
                  Obx(() => TextButton(
                    onPressed: isGenerating.value
                        ? null
                        : () async {
                            isGenerating.value = true;
                            try {
                              generatedText = await _modifyText(
                                selectedText,
                                requirementController.text,
                              );
                            } finally {
                              isGenerating.value = false;
                            }
                          },
                    child: const Text('生成'),
                  )),
                  const SizedBox(width: 8),
                  Obx(() => ElevatedButton(
                    onPressed: isGenerating.value
                        ? null
                        : () async {
                            if (generatedText == null) {
                              isGenerating.value = true;
                              try {
                                generatedText = await _modifyText(
                                  selectedText,
                                  requirementController.text,
                                );
                              } finally {
                                isGenerating.value = false;
                              }
                            }
                            
                            if (generatedText != null && generatedText!.isNotEmpty) {
                              final newText = textController.text.replaceRange(
                                selection.start,
                                selection.end,
                                generatedText!,
                              );
                              textController.text = newText;
                              Get.back();
                            }
                          },
                    child: const Text('应用修改'),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 修改文本
  Future<String> _modifyText(String text, String requirement) async {
    final prompt = '''请修改以下文本：

原文：$text

${requirement.isNotEmpty ? '修改要求：$requirement' : '要求：保持文本的基本含义，适当优化表达'}

请直接给出修改后的文本，不要包含任何解释或说明。''';

    String response = '';
    await for (final chunk in aiService.generateTextStream(
      model: AIModel.deepseek,
      systemPrompt: '你是一位专业的文字编辑，擅长根据要求优化和改写文本。',
      userPrompt: prompt,
    )) {
      response += chunk;
    }
    return response;
  }
} 