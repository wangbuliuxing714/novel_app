import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/editor_controller.dart';
import 'package:novel_app/controllers/outline_controller.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'dart:async';  // 添加 dart:async 导入以使用 unawaited

class ChapterAddController extends GetxController {
  final aiService = Get.find<AIService>();
  final editorController = Get.find<EditorController>();
  final outlineController = Get.find<OutlineController>();
  final apiConfig = Get.find<ApiConfigController>();
  
  final titleController = TextEditingController();
  final isGenerating = false.obs;
  final detailedOutline = ''.obs;
  
  @override
  void onClose() {
    titleController.dispose();
    super.onClose();
  }
  
  // 获取之前所有章节的内容
  String _getPreviousChaptersContent() {
    final chapters = outlineController.chapters;
    if (chapters.isEmpty) return '这是第一章，暂无之前的章节内容。';

    // 构建完整的故事上下文
    final buffer = StringBuffer();
    
    // 添加总体信息
    buffer.writeln('已有章节数：${chapters.length}');
    buffer.writeln();
    
    // 添加每个章节的内容
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      buffer.writeln('第${i + 1}章：${chapter.title}');
      buffer.writeln(chapter.content);
      buffer.writeln();  // 章节之间添加空行
    }

    return buffer.toString();
  }
  
  // 获取最近的几个章节内容
  String _getRecentChaptersContent([int count = 3]) {
    final chapters = outlineController.chapters;
    if (chapters.isEmpty) return '这是第一章，暂无之前的章节内容。';

    // 获取最近的几个章节
    final recentChapters = chapters.length <= count 
        ? chapters 
        : chapters.sublist(chapters.length - count);

    // 构建上下文
    final buffer = StringBuffer();
    
    // 添加总体信息
    buffer.writeln('总章节数：${chapters.length}');
    buffer.writeln('当前正在创作第${chapters.length + 1}章');
    buffer.writeln();
    
    // 添加最近几章的内容
    for (var i = 0; i < recentChapters.length; i++) {
      final chapter = recentChapters[i];
      final chapterNumber = chapters.length - recentChapters.length + i + 1;
      buffer.writeln('第$chapterNumber章：${chapter.title}');
      buffer.writeln(chapter.content);
      buffer.writeln();  // 章节之间添加空行
    }

    return buffer.toString();
  }
  
  // 生成详细大纲
  Future<void> generateDetailedOutline() async {
    if (titleController.text.isEmpty) {
      Get.snackbar('提示', '请先输入章节简要情节');
      return;
    }
    
    isGenerating.value = true;
    try {
      // 获取所有之前章节的内容作为上下文
      final previousChapters = _getPreviousChaptersContent();
      
      final prompt = '''请基于以下内容创作一个详细的章节大纲：

之前的章节内容：
$previousChapters

新章节简要情节：${titleController.text}

创作要求：
- 开场要自然承接上文的情节和氛围，设置合适的场景和人物状态
- 按照事件发生的自然顺序展开情节，避免使用时间标记
- 场景切换要流畅，避免突兀的跳转
- 人物的行为和对话要符合其性格特点，体现人物关系的发展
- 情节要有起伏变化，设置合理的转折点
- 结尾要为后续发展预留伏笔，但要自然不刻意
- 使用简洁直白的语言描述
- 避免使用标题、序号等标记
- 保持逻辑清晰，便于理解
- 注重情节的连贯性和完整性
- 确保与之前所有章节的情节、人物发展保持一致性

请直接描述情节发展，不需要任何额外的说明、标记或分段。''';

      String response = '';
      await for (final chunk in aiService.generateTextStream(
        model: apiConfig.selectedModel.value,
        systemPrompt: '你是一位擅长结构化写作的策划，注重情节连贯性和人物塑造。请仔细阅读之前所有章节的内容，创作出流畅自然且与整体故事连贯的大纲。',
        userPrompt: prompt,
      )) {
        response += chunk;
        detailedOutline.value = response;
      }
    } catch (e) {
      Get.snackbar('错误', '生成详细大纲失败，请重试');
    } finally {
      isGenerating.value = false;
    }
  }
  
  // 编辑详细大纲
  void editDetailedOutline() {
    final screenHeight = Get.height;
    final textController = TextEditingController(text: detailedOutline.value);
    
    Get.dialog(
      Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.8,
            maxWidth: 600,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '编辑详细大纲',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onChanged: (value) => detailedOutline.value = value,
                    contextMenuBuilder: (context, editableTextState) {
                      final TextEditingValue value = editableTextState.textEditingValue;
                      
                      if (value.selection.isValid && !value.selection.isCollapsed) {
                        final selectedText = value.text.substring(
                          value.selection.start,
                          value.selection.end,
                        );
                        
                        return AdaptiveTextSelectionToolbar(
                          anchors: editableTextState.contextMenuAnchors,
                          children: [
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () {
                                editableTextState.hideToolbar();
                                unawaited(_showAIEditDialog(
                                  selectedText,
                                  value.selection,
                                  textController,
                                ));
                              },
                              child: const Text(
                                'AI修改',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () {
                                editableTextState.hideToolbar();
                                unawaited(Clipboard.setData(ClipboardData(text: selectedText)));
                              },
                              child: const Text(
                                '复制',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () {
                                editableTextState.hideToolbar();
                                unawaited(Clipboard.setData(ClipboardData(text: selectedText)));
                                final newText = textController.text.replaceRange(
                                  value.selection.start,
                                  value.selection.end,
                                  '',
                                );
                                textController.text = newText;
                                detailedOutline.value = newText;
                              },
                              child: const Text(
                                '剪切',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  final newText = textController.text.replaceRange(
                                    value.selection.start,
                                    value.selection.end,
                                    data!.text!,
                                  );
                                  textController.text = newText;
                                  detailedOutline.value = newText;
                                }
                                editableTextState.hideToolbar();
                              },
                              child: const Text(
                                '粘贴',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: editableTextState.contextMenuButtonItems,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        detailedOutline.value = textController.text;
                        Get.back();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // 获取AI修改建议
  Future<String> _getAIEditSuggestion(String text) async {
    final prompt = '''请对以下文本进行修改和优化。要求：
1. 使用直白清晰的语言
2. 避免过度修饰和比喻
3. 保持逻辑性和连贯性
4. 突出重要信息

原文：$text

请给出修改后的文本。''';

    try {
      String response = '';
      await for (final chunk in aiService.generateTextStream(
        model: apiConfig.selectedModel.value,
        systemPrompt: '你是一位专注于清晰表达的编辑，擅长用直白的语言传达信息。',
        userPrompt: prompt,
      )) {
        response += chunk;
      }
      return response;
    } catch (e) {
      return '生成建议失败：$e';
    }
  }
  
  // AI修改对话框
  Future<void> _showAIEditDialog(
    String selectedText,
    TextSelection selection,
    TextEditingController textController,
  ) async {
    final result = await Get.dialog<bool>(
      Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AI修改建议',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<String>(
                future: _getAIEditSuggestion(selectedText),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Text('生成建议失败：${snapshot.error}');
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(snapshot.data ?? ''),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(result: false),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (snapshot.data != null) {
                                final newText = textController.text.replaceRange(
                                  selection.start,
                                  selection.end,
                                  snapshot.data!,
                                );
                                textController.text = newText;
                                detailedOutline.value = newText;
                              }
                              Get.back(result: true);
                            },
                            child: const Text('应用修改'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      print('修改已应用');
    } else {
      print('修改已取消');
    }
  }
  
  // 确认并生成章节内容
  Future<void> confirmAndGenerate() async {
    if (detailedOutline.value.isEmpty) {
      Get.snackbar('提示', '请先生成或编辑详细大纲');
      return;
    }
    
    if (titleController.text.isEmpty) {
      Get.snackbar('提示', '请输入章节标题');
      return;
    }
    
    isGenerating.value = true;
    try {
      // 获取所有章节内容作为上下文
      final previousChapters = _getPreviousChaptersContent();
      
      final prompt = '''请基于以下内容来创作新的章节：

之前的章节内容：
$previousChapters

新章节标题：${titleController.text}

详细大纲：
${detailedOutline.value}

创作要求：
- 内容要自然连贯，避免使用时间标记（如"清晨6:00"）或章节标记（如"1."、"第一部分"等）
- 按照事件发生的自然顺序展开情节，而不是生硬的时间顺序
- 场景切换要流畅自然，避免突兀的跳转
- 保持与前文的连贯性，自然承接之前的情节
- 人物性格和行为要与之前的描写保持一致
- 场景描写要生动具体，注重细节和氛围营造
- 对话要体现人物性格和关系的发展
- 为后续发展预留伏笔
- 使用优美流畅的语言，但避免过度修饰
- 创作时要注重情节的连贯性和完整性，不要分段或加入标题

请直接开始创作，不需要任何额外的说明、标记或分段。''';

      String response = '';
      await for (final chunk in aiService.generateTextStream(
        model: apiConfig.selectedModel.value,
        systemPrompt: '你是一位专业的小说写手，擅长叙事和人物刻画。请创作出流畅自然、富有感染力的章节内容，不要使用任何标记或分段。',
        userPrompt: prompt,
      )) {
        response += chunk;
      }

      // 先保存当前编辑器的内容（如果有正在编辑的章节）
      final currentChapter = outlineController.getSelectedChapter();
      if (currentChapter != null) {
        outlineController.updateChapterContent(
          currentChapter.id,
          editorController.contentController.text,
        );
      }

      // 添加新章节
      final chapterId = outlineController.addChapter(titleController.text);
      
      // 更新新章节的内容
      outlineController.updateChapterContent(chapterId, response);
      
      // 选中新章节
      outlineController.selectChapter(chapterId);
      
      // 更新编辑器内容
      editorController.titleController.text = titleController.text;
      editorController.contentController.text = response;
      
      Get.back(); // 关闭对话框
      Get.snackbar('成功', '新章节已生成');
    } catch (e) {
      Get.snackbar('错误', '生成章节内容失败，请重试');
    } finally {
      isGenerating.value = false;
    }
  }
} 