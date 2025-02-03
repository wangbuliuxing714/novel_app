import 'package:get/get.dart';
import 'dart:async';
import 'package:novel_app/controllers/editor_controller.dart';
import 'package:novel_app/controllers/outline_controller.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:novel_app/controllers/api_config_controller.dart';

class AIAdvisorController extends GetxController {
  final editorController = Get.find<EditorController>();
  final outlineController = Get.find<OutlineController>();
  final aiService = Get.find<AIService>();
  final apiConfig = Get.find<ApiConfigController>();
  
  // 状态变量
  final isAnalyzing = false.obs;
  final suggestions = <String>[].obs;
  final currentContext = ''.obs;
  final questionController = TextEditingController();
  
  // 分析定时器
  Timer? _analysisTimer;
  Timer? _debounceTimer;
  
  @override
  void onInit() {
    super.onInit();
    // 设置定时分析
    _setupAnalysisTimer();
    // 监听编辑器内容变化
    _setupContentListener();
  }
  
  @override
  void onClose() {
    _analysisTimer?.cancel();
    _debounceTimer?.cancel();
    questionController.dispose();
    super.onClose();
  }
  
  // 设置定时分析（每60秒）
  void _setupAnalysisTimer() {
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      analyzeContent();
    });
  }
  
  // 监听编辑器内容变化
  void _setupContentListener() {
    editorController.contentController.addListener(() {
      // 使用防抖，避免频繁分析
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 3), () {
        updateCurrentContext();
      });
    });
  }
  
  // 更新当前上下文
  void updateCurrentContext() {
    final title = editorController.titleController.text;
    final content = editorController.contentController.text;
    currentContext.value = '$title\n\n$content';
  }
  
  // 分析内容并生成建议
  Future<void> analyzeContent() async {
    if (isAnalyzing.value) return;
    
    final chapter = outlineController.getSelectedChapter();
    if (chapter == null) return;
    
    isAnalyzing.value = true;
    suggestions.clear();
    
    try {
      final title = editorController.titleController.text;
      final content = editorController.contentController.text;
      
      // 获取前一章内容（如果有）
      String previousChapter = '';
      final currentIndex = outlineController.chapters.indexWhere((c) => c.id == chapter.id);
      if (currentIndex > 0) {
        previousChapter = outlineController.chapters[currentIndex - 1].content;
      }
      
      // 构建提示词
      final prompt = '''作为专业的小说顾问，请对当前章节进行分析并给出建议：

当前章节标题：$title
前一章内容：${previousChapter.isEmpty ? '无' : previousChapter}
当前内容：$content

请从以下几个方面进行分析并给出具体建议：
1. 情节连贯性：与前文的关联和过渡是否自然
2. 人物塑造：性格是否前后一致，行为是否合理
3. 场景描写：是否生动形象，细节是否到位
4. 节奏把控：是否有张有弛，是否有高潮
5. 伏笔设置：是否为后续发展埋下伏笔

请直接列出具体的改进建议，每条建议需要具体明确。''';

      // 使用AI服务生成建议，使用当前选择的模型
      String response = '';
      await for (final chunk in aiService.generateTextStream(
        model: apiConfig.selectedModel.value,
        systemPrompt: '你是一位专业的小说顾问，擅长分析情节、人物、场景等各个方面，并给出具体的改进建议。',
        userPrompt: prompt,
      )) {
        response += chunk;
        // 实时更新建议列表
        suggestions.value = _parseSuggestions(response);
      }
      
    } catch (e) {
      Get.snackbar(
        '分析失败',
        '请检查网络连接后重试',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isAnalyzing.value = false;
    }
  }
  
  // 解析AI返回的建议文本
  List<String> _parseSuggestions(String response) {
    // 按行分割，去除空行
    return response
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), ''))
      .toList();
  }
  
  // 获取指定类型的建议
  Future<void> getSpecificAdvice(String type) async {
    if (isAnalyzing.value) return;
    
    isAnalyzing.value = true;
    suggestions.clear();
    
    try {
      final content = editorController.contentController.text;
      String prompt = '';
      
      switch (type) {
        case '情节推演':
          prompt = '''分析当前情节发展，并给出以下建议：
1. 后续情节可能的发展方向
2. 需要注意的情节漏洞
3. 可以强化的戏剧冲突
4. 情节高潮的设置建议
当前内容：$content''';
          break;
          
        case '人物塑造':
          prompt = '''分析当前人物塑造，并给出以下建议：
1. 人物性格的立体化
2. 人物行为的合理性
3. 人物对话的个性化
4. 人物关系的深化
当前内容：$content''';
          break;
          
        case '场景描写':
          prompt = '''分析当前场景描写，并给出以下建议：
1. 场景细节的补充
2. 环境氛围的营造
3. 感官描写的丰富
4. 场景与情节的呼应
当前内容：$content''';
          break;
          
        case '对话优化':
          prompt = '''分析当前对话内容，并给出以下建议：
1. 对话的自然流畅度
2. 人物语气的个性化
3. 对话节奏的把控
4. 潜台词的设置
当前内容：$content''';
          break;
          
        case '文风调整':
          prompt = '''分析当前文风，并给出以下建议：
1. 文字风格的统一性
2. 描写手法的多样化
3. 语言节奏的优化
4. 修辞手法的运用
当前内容：$content''';
          break;
      }
      
      String response = '';
      await for (final chunk in aiService.generateTextStream(
        model: apiConfig.selectedModel.value,
        systemPrompt: '你是一位专业的小说顾问，请针对特定方面给出具体的改进建议。',
        userPrompt: prompt,
      )) {
        response += chunk;
        suggestions.value = _parseSuggestions(response);
      }
      
    } catch (e) {
      Get.snackbar(
        '分析失败',
        '请检查网络连接后重试',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isAnalyzing.value = false;
    }
  }
  
  // 处理自定义问题
  Future<void> handleCustomQuestion(String question) async {
    if (question.isEmpty) return;
    
    isAnalyzing.value = true;
    suggestions.clear();
    
    try {
      final chapter = outlineController.getSelectedChapter();
      if (chapter == null) {
        Get.snackbar('提示', '请先选择一个章节');
        return;
      }
      
      final title = editorController.titleController.text;
      final content = editorController.contentController.text;
      
      // 构建提示词
      final prompt = '''作为专业的小说顾问，请根据以下内容回答问题：

当前章节标题：$title
当前内容：$content

用户问题：$question

请给出详细的回答和建议。''';

      String response = '';
      await for (final chunk in aiService.generateTextStream(
        model: apiConfig.selectedModel.value,
        systemPrompt: '你是一位专业的小说顾问，擅长分析情节、人物、场景等各个方面，并给出具体的建议。',
        userPrompt: prompt,
      )) {
        response += chunk;
        suggestions.value = _parseSuggestions(response);
      }
      
      // 清空输入框
      questionController.clear();
      
    } catch (e) {
      Get.snackbar(
        '分析失败',
        '请检查网络连接后重试',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isAnalyzing.value = false;
    }
  }
} 