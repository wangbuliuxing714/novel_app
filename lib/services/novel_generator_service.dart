import 'package:get/get.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/prompts/master_prompts.dart';
import 'package:novel_app/prompts/outline_generation.dart';
import 'package:novel_app/prompts/chapter_generation.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:novel_app/prompts/character_prompts.dart';
import 'package:novel_app/prompts/male_prompts.dart';
import 'package:novel_app/prompts/female_prompts.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/screens/outline_preview_screen.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'dart:convert';
import 'dart:async';
import 'package:hive/hive.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/models/prompt_package.dart';
import 'dart:math';
import 'package:novel_app/models/novel_outline.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/prompts/short_novel_female_prompts.dart';
import 'package:novel_app/prompts/short_novel_male_prompts.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

class ParagraphInfo {
  final String content;
  final String hash;
  final List<String> keywords;
  final DateTime timestamp;

  ParagraphInfo(this.content) :
    hash = _generateHash(content),
    keywords = _extractKeywords(content),
    timestamp = DateTime.now();

  static String _generateHash(String content) {
    return content.hashCode.toString();
  }

  static List<String> _extractKeywords(String content) {
    // 简单的关键词提取：去除常用词，保留主要名词、动词等
    final words = content.split(RegExp(r'[\s,。，！？.!?]'));
    final stopWords = {'的', '了', '和', '与', '在', '是', '都', '而', '又', '也', '就'};
    return words.where((word) => 
      word.length >= 2 && !stopWords.contains(word)
    ).toList();
  }
}

class DuplicateCheckResult {
  final bool isDuplicate;
  final double similarity;
  final String duplicateSource;
  final List<String> duplicateKeywords;

  DuplicateCheckResult({
    required this.isDuplicate,
    required this.similarity,
    this.duplicateSource = '',
    this.duplicateKeywords = const [],
  });
}

class NovelGeneratorService extends GetxService {
  static const double HIGH_SIMILARITY_THRESHOLD = 0.8;
  static const double MEDIUM_SIMILARITY_THRESHOLD = 0.6;
  
  final AIService _aiService;
  final ApiConfigController _apiConfig;
  final CacheService _cacheService;
  final void Function(String)? onProgress;
  final String targetReaders = "青年读者";
  final RxList<ParagraphInfo> _generatedParagraphs = <ParagraphInfo>[].obs;
  final RxInt _currentGeneratingChapter = 0.obs;
  final RxBool _isGenerating = false.obs;
  final RxString _lastError = ''.obs;
  final RxString _currentNovelTitle = ''.obs;
  final RxString _currentNovelOutline = ''.obs;
  final RxList<Chapter> _generatedChapters = <Chapter>[].obs;
  final RxBool _isPaused = false.obs;
  Completer<void>? _pauseCompleter;
  String style = '';
  String _content = ''; // 用于存储内容

  // 添加新的成员变量
  late Function(String) _updateRealtimeOutput;
  late Function(String) _updateGenerationStatus;
  late Function(double) _updateGenerationProgress;

  // 用于存储失败的生成尝试，避免重复生成相同的失败内容
  final Map<String, List<String>> _failedGenerationCache = {};
  
  // 用于暂停和恢复生成
  final RxBool _shouldStop = false.obs;

  NovelGeneratorService(
    this._aiService, 
    this._cacheService, 
    this._apiConfig,
    {this.onProgress}
  );

  @override
  void onInit() {
    super.onInit();
  }

  // 获取当前生成状态的getter
  int get currentGeneratingChapter => _currentGeneratingChapter.value;
  bool get isGenerating => _isGenerating.value;
  bool get isPaused => _isPaused.value;  // 添加暂停状态getter
  String get lastError => _lastError.value;
  List<Chapter> get generatedChapters => _generatedChapters;
  String get currentNovelTitle => _currentNovelTitle.value;
  String get currentNovelOutline => _currentNovelOutline.value;

  // getter和setter
  String get content => _content;
  set content(String value) => _content = value;

  void _updateProgress(String status, [double progress = 0.0]) {
    _updateGenerationStatus(status);
    if (progress > 0) {
      _updateGenerationProgress(progress);
    }
  }

  // 在生成章节前检查缓存
  Future<String?> _checkCache(String chapterKey) async {
    return _cacheService.getContent(chapterKey);
  }

  // 检查章节大纲内容的连贯性
  Future<String> _ensureOutlineCoherence(String newOutlineContent, String previousOutlineContent) async {
    // 如果没有之前的内容作为参考，直接返回新内容
    if (previousOutlineContent.isEmpty) {
      return newOutlineContent;
    }
    
    // 检测连贯性问题的关键词
    final List<String> coherenceIssueKeywords = [
      '前后矛盾', '情节断层', '性格变化', '突然出现', '莫名其妙', 
      '无法解释', '缺乏连续性', '不一致', '突兀'
    ];
    
    // 构建检查连贯性的提示词
    final checkPrompt = '''
请分析以下两部分小说大纲内容，检查它们之间是否存在连贯性问题：

第一部分（先前的大纲内容）：
$previousOutlineContent

第二部分（新生成的大纲内容）：
$newOutlineContent

请仅回答"有连贯性问题"或"无连贯性问题"。
''';

    // 检查连贯性
    String coherenceCheckResult = '';
    try {
      coherenceCheckResult = await _aiService.generateText(
        systemPrompt: "你是一个专业的小说编辑助手，请检查两段大纲内容之间是否存在连贯性问题，如情节断层、人物行为不一致等。只回答'有连贯性问题'或'无连贯性问题'。",
        userPrompt: checkPrompt,
        temperature: 0.2, // 低温度，提高确定性
        maxTokens: 50, // 简短回答即可
      );
    } catch (e) {
      print('检查大纲连贯性失败: $e');
      return newOutlineContent; // 出错时返回原始内容
    }
    
    // 如果检测到连贯性问题，尝试修复
    if (coherenceCheckResult.toLowerCase().contains("有连贯性问题")) {
      print('检测到大纲连贯性问题，尝试修复...');
      try {
        // 构建修复提示词
        final fixPrompt = '''
请修复以下小说大纲内容之间存在的连贯性问题。确保修复后的内容在情节发展、人物行为和设定上保持一致性。

第一部分（先前的大纲内容，不需要修改）：
$previousOutlineContent

第二部分（需要修复的大纲内容）：
$newOutlineContent

请提供修复后的第二部分内容，确保与第一部分情节和人物发展保持连贯。
''';

        // 尝试修复连贯性问题
        String fixedContent = await _aiService.generateText(
          systemPrompt: "你是一个专业的小说编辑助手，请修复两段大纲内容之间的连贯性问题，确保情节发展自然，人物行为一致，设定不冲突。",
          userPrompt: fixPrompt,
          temperature: 0.7,
          maxTokens: 2000,
        );
        
        // 如果修复后的内容不为空，返回修复后的内容
        if (fixedContent.isNotEmpty) {
          print('大纲连贯性问题修复完成');
          return fixedContent;
        }
      } catch (e) {
        print('修复大纲连贯性失败: $e');
      }
    }
    
    // 如果没有问题或修复失败，返回原始内容
    return newOutlineContent;
  }

  // 保存生成的内容到缓存
  Future<void> _cacheContent(String chapterKey, String content) async {
    await _cacheService.cacheContent(chapterKey, content);
  }

  // 检查段落是否重复
  bool _isParagraphDuplicate(String paragraph) {
    return _generatedParagraphs.contains(paragraph);
  }

  // 添加新生成的段落到记录中
  void _addGeneratedParagraph(String paragraph) {
    _generatedParagraphs.add(ParagraphInfo(paragraph));
    // 保持最近1000个段落的记录
    if (_generatedParagraphs.length > 1000) {
      _generatedParagraphs.removeAt(0);
    }
  }

  Future<String> generateOutline({
    required String title,
    required String genre,
    required String theme,
    required String targetReaders,
    required int totalChapters,
    Map<String, CharacterCard>? characterCards,
    List<CharacterType>? characterTypes,
    void Function(String)? onProgress,
    void Function(String)? onContent,
    bool isShortNovel = false,
    int wordCount = 10000,
  }) async {
    try {
      // 基本提示词
      String masterPrompt = OutlineGeneration.getSystemPrompt(title, genre, theme);
      String outlinePrompt = '';
      
      // 目标读者提示词
      String targetReaderPrompt = '';
      if (targetReaders.isNotEmpty) {
        targetReaderPrompt = '''
目标读者：$targetReaders
请确保故事内容、风格和表达方式符合目标读者的喜好和阅读习惯。
''';
      }
      
      // 角色信息提示词
      String characterPrompt = '';
      if (characterCards != null && characterCards.isNotEmpty && characterTypes != null && characterTypes.isNotEmpty) {
        characterPrompt = '主要角色信息：\n\n';
        for (final type in characterTypes) {
          final card = characterCards[type.id];
          if (card != null && card.name.isNotEmpty) {
            characterPrompt += '角色：${card.name}\n';
            
            if (card.age != null && card.age!.isNotEmpty) {
              characterPrompt += '年龄：${card.age}\n';
            }
            
            if (card.gender != null && card.gender!.isNotEmpty) {
              characterPrompt += '性别：${card.gender}\n';
            }
            
            if (card.bodyDescription != null && card.bodyDescription!.isNotEmpty) {
              characterPrompt += '外貌：${card.bodyDescription}\n';
            }
            
            if (card.personalityTraits != null && card.personalityTraits!.isNotEmpty) {
              characterPrompt += '性格：${card.personalityTraits}\n';
            }
            
            if (card.background != null && card.background!.isNotEmpty) {
              characterPrompt += '背景：${card.background}\n';
            }
            
            if (card.shortTermGoals != null && card.shortTermGoals!.isNotEmpty) {
              characterPrompt += '短期目标：${card.shortTermGoals}\n';
            }
            
            if (card.longTermGoals != null && card.longTermGoals!.isNotEmpty) {
              characterPrompt += '长期目标：${card.longTermGoals}\n';
            }
            
            characterPrompt += '\n';
          }
        }
      }
      
      // 根据目标读者选择不同的提示词
      String outlineFormatPrompt = '';
      if (isShortNovel) {
        // 生成短篇小说大纲
        if (targetReaders == '女性向') {
          // 使用女性向短篇提示词
          outlineFormatPrompt = FemalePrompts.getShortNovelOutlinePrompt(title, genre, theme, wordCount);
        } else {
          // 默认使用男性向短篇提示词
          outlineFormatPrompt = MalePrompts.getShortNovelOutlinePrompt(title, genre, theme, wordCount);
        }
      } else {
        // 生成长篇小说大纲
        if (targetReaders == '女性向') {
          // 使用女性向提示词
          outlineFormatPrompt = FemalePrompts.getOutlinePrompt(title, genre, theme, totalChapters);
        } else {
          // 默认使用男性向提示词
          outlineFormatPrompt = MalePrompts.getOutlinePrompt(title, genre, theme, totalChapters);
        }
      }
      
      // 构建基础提示词
      final basePrompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${outlinePrompt.isNotEmpty ? outlinePrompt + '\n\n' : ''}
${targetReaderPrompt.isNotEmpty ? targetReaderPrompt + '\n\n' : ''}
${characterPrompt.isNotEmpty ? characterPrompt + '\n\n' : ''}
''';

      // 分批生成大纲
      final StringBuffer fullOutlineBuffer = StringBuffer();
      
      // 获取大纲对话ID
      final outlineConversationId = '_outline_${title.replaceAll(' ', '_')}';
      
      // 添加大纲的整体结构和主要情节线（只生成一次）
      if (onProgress != null) {
        onProgress('正在生成小说整体结构...');
      }
      
      // 构建第一部分提示词（整体结构和主要情节线）
      final structurePrompt = '''
$basePrompt
请为这部名为《$title》的$genre小说创作大纲的前两部分：整体架构和主要情节线。
不要生成具体章节内容，只需要完成整体架构和主要情节线两部分。

大纲格式要求：
1. 第一层：整体架构（三幕式结构）
   - 开端（约占20%）：介绍背景、人物、核心冲突
   - 发展（约占60%）：矛盾升级、情节推进、人物成长
   - 高潮（约占20%）：最终决战、结局呈现

2. 第二层：主要情节线
   - 主线：核心冲突的发展脉络
   - 支线A：重要人物关系发展
   - 支线B：次要矛盾发展
   （根据需要可以有更多支线）

请按照以下格式输出：

一、整体架构
[详细说明三幕式结构的具体内容]

二、主要情节线
[列出主线和重要支线的发展脉络]
''';

      // 生成整体结构
      String structureContent = '';
      await for (final chunk in _aiService.generateOutlineTextStream(
        systemPrompt: structurePrompt,
        userPrompt: "请仅生成整体架构和主要情节线部分，不要生成具体章节",
        maxTokens: _getMaxTokensForChapter(0),
        temperature: 0.7,
        conversationId: outlineConversationId,
      )) {
        structureContent += chunk;
        if (onContent != null) {
          onContent(chunk);
        }
      }
      
      fullOutlineBuffer.writeln(structureContent.trim());
      fullOutlineBuffer.writeln("\n三、具体章节");
      
      // 将结构和情节线保存下来，用于后续章节生成参考
      final String structureAndPlotContent = structureContent.trim();
      
      // 保存已生成的章节大纲内容，用于后续章节生成参考
      StringBuffer generatedChaptersBuffer = StringBuffer();
      
      // 分批生成章节大纲
      final int batchSize = 5; // 减少每批处理的章节数，提高连贯性
      for (int startChapter = 1; startChapter <= totalChapters; startChapter += batchSize) {
        final int endChapter = (startChapter + batchSize - 1) > totalChapters 
            ? totalChapters 
            : (startChapter + batchSize - 1);
            
        if (onProgress != null) {
          onProgress('正在生成第$startChapter-$endChapter章大纲...');
        }
        
        // 构建参考上下文，让AI了解已生成的内容
        String contextReference = '';
        if (startChapter > 1 && generatedChaptersBuffer.isNotEmpty) {
          // 只提供最近生成的部分作为上下文，避免上下文过长
          contextReference = '''
这是已经生成的章节大纲，请确保新生成的章节与之保持情节连贯性：

${generatedChaptersBuffer.toString().trim()}

请继续完成后续章节大纲，保持情节的自然发展和人物成长的连贯性。
''';
        }
        
        // 构建章节批次提示词
        final batchPrompt = '''
$basePrompt

${structureAndPlotContent}

${contextReference.isNotEmpty ? contextReference + '\n\n' : ''}

请为这部名为《$title》的$genre小说创作第$startChapter章到第$endChapter章的大纲。

创作要求：
$theme
请严格按照前面的整体架构和主要情节线安排，确保故事情节连贯，不要出现逻辑断层。
请注意主要角色的发展弧线，确保角色行为与其性格特点和目标一致。

大纲格式要求：
每章需包含：
- 章节标题（简洁有力）
- 主要情节（2-3个关键点）
- 次要情节（1-2个补充点）
- 人物发展（重要人物的变化）
- 伏笔/悬念（如果有）

请按照以下格式输出：

${startChapter == 1 ? '' : '继续上文，'}从第$startChapter章开始：

第${startChapter}章：章节标题
主要情节：
- 情节点1
- 情节点2
次要情节：
- 情节点A
人物发展：
- 变化点1
伏笔/悬念：
- 伏笔点1

第${startChapter+1}章：...（后续章节）
''';

        // 使用智能大纲生成
        String batchContent = '';
        if (startChapter > 1 && generatedChaptersBuffer.isNotEmpty) {
          // 使用带有上下文的智能大纲生成
          final userPrompt = "请按照要求生成第$startChapter到第$endChapter章的详细大纲，确保与前面章节情节连贯";
          
          if (onProgress != null) {
            onProgress('正在使用智能生成模式创建大纲...');
          }
          
          try {
            // 获取前一批次的内容作为上下文
            String previousContent = generatedChaptersBuffer.toString().trim();
            // 限制前一部分的长度，避免提示词过长
            if (previousContent.length > 3000) {
              previousContent = previousContent.substring(previousContent.length - 3000);
            }
            
            // 使用智能大纲生成
            batchContent = await _aiService.generateSmartOutline(
              prompt: batchPrompt,
              previousContent: previousContent,
              temperature: 0.7,
              maxTokens: _getMaxTokensForChapter(0) * 2,
              conversationId: outlineConversationId,
            );
            
            if (onContent != null) {
              onContent(batchContent);
            }
          } catch (e) {
            print('智能大纲生成失败，切换到标准模式: $e');
            // 智能生成失败，回退到标准流式生成
            if (onProgress != null) {
              onProgress('智能模式失败，切换到标准模式...');
            }
            
            // 使用标准流式生成
            await for (final chunk in _aiService.generateOutlineTextStream(
              systemPrompt: batchPrompt,
              userPrompt: "请按照要求生成第$startChapter到第$endChapter章的详细大纲，确保与前面章节情节连贯",
              maxTokens: _getMaxTokensForChapter(0) * 2,
              temperature: 0.7,
              conversationId: outlineConversationId,
            )) {
              batchContent += chunk;
              if (onContent != null) {
                onContent(chunk);
              }
            }
          }
        } else {
          // 第一批次使用标准流式生成
          await for (final chunk in _aiService.generateOutlineTextStream(
            systemPrompt: batchPrompt,
            userPrompt: "请按照要求生成第$startChapter到第$endChapter章的详细大纲",
            maxTokens: _getMaxTokensForChapter(0) * 2,
            temperature: 0.7,
            conversationId: outlineConversationId,
          )) {
            batchContent += chunk;
            if (onContent != null) {
              onContent(chunk);
            }
          }
        }
        
        // 处理批次内容，移除可能的额外标题
        String processedBatch = batchContent.trim();
        if (startChapter > 1) {
          // 如果不是第一批，移除可能出现的"三、具体章节"标题
          processedBatch = processedBatch.replaceFirst(RegExp(r'^三、具体章节\s*', multiLine: true), '');
          
          // 检查并修复连贯性问题
          if (generatedChaptersBuffer.isNotEmpty) {
            if (onProgress != null) {
              onProgress('正在检查大纲连贯性...');
            }
            // 获取前一批次的最后部分作为参考上下文
            String previousContent = generatedChaptersBuffer.toString().trim();
            // 限制前一部分的长度，避免提示词过长
            if (previousContent.length > 2000) {
              previousContent = previousContent.substring(previousContent.length - 2000);
            }
            
            // 检查并修复连贯性
            processedBatch = await _ensureOutlineCoherence(processedBatch, previousContent);
            
            if (onProgress != null) {
              onProgress('大纲连贯性检查完成，继续生成...');
            }
          }
        }
        
        fullOutlineBuffer.writeln(processedBatch);
        
        // 保存这一批次的内容，用于后续参考
        generatedChaptersBuffer.writeln(processedBatch);
        
        // 如果生成内容过长，只保留最近的几个章节作为上下文
        if (generatedChaptersBuffer.length > 4000) {
          String currentContent = generatedChaptersBuffer.toString();
          // 保留后半部分
          generatedChaptersBuffer = StringBuffer();
          generatedChaptersBuffer.write(currentContent.substring(currentContent.length ~/ 2));
        }
        
        // 短暂延迟，避免API限流
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 格式化完整大纲
      String outlineContent = OutlineGeneration.formatOutline(fullOutlineBuffer.toString());
      
      if (onProgress != null) {
        if (isShortNovel) {
          onProgress('短篇小说大纲生成完成');
        } else {
          onProgress('大纲生成完成');
        }
      }

      return outlineContent;
    } catch (e) {
      print('生成大纲失败: $e');
      throw Exception('生成大纲失败: $e');
    }
  }

  Future<Chapter> generateChapter({
    required String title,
    required String outline,
    required int number,
    required int totalChapters,
    required List<Chapter> previousChapters,
    String? style,
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      // 解析章节规划
      final chapterPlans = _parseOutline(outline);
      
      // 构建章节上下文
      final context = _buildChapterContext(
        outline: outline,
        previousChapters: previousChapters,
        currentNumber: number,
        totalChapters: totalChapters,
      );
      
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final novelController = Get.find<NovelController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(novelController.targetReader.value);
      
      // 没有指定风格时使用默认风格策略
      final currentStyle = style ?? _determineStyle(number, totalChapters, null);
      
      // 构建完整提示词
      final prompt = '''
${context}

${masterPrompt.isNotEmpty ? "全局指导：\n" + masterPrompt + "\n\n" : ""}
${targetReaderPrompt.isNotEmpty ? "目标读者：\n" + targetReaderPrompt + "\n\n" : ""}

写作要求：
1. 创作风格：$currentStyle
2. 不要以"第X章"或章节标题开头
3. 详细展开本章情节，符合大纲中描述的内容和主题
4. 与前文保持连贯，延续已建立的情节线和角色发展
5. 章节长度控制在3000-5000字之间
6. 不要在正文中出现"未完待续"等结束语
''';

      // 使用AI服务生成内容
      onProgress?.call('正在生成第$number章...');
      
      // 如果有onContent回调，使用它来显示生成进度
      if (onContent != null) {
        onContent('\n开始生成第$number章内容...\n');
      }
      
      // 提取大纲内容
      String outlineForChapter = "";
      if (chapterPlans.containsKey(number)) {
        outlineForChapter = chapterPlans[number]?['content'] ?? "";
      }
      
      // 使用对话ID生成章节内容，并传递小说大纲
      final generatedContent = await _aiService.generateChapterContent(
        prompt, 
        novelTitle: title, 
        chapterNumber: number,
        outlineContent: outline  // 传递整个大纲，不只是当前章节的大纲
      );
      
      // 清理内容格式
      String cleanedContent = _cleanGeneratedContent(generatedContent);
      
      // 检查章节连贯性并修复问题（即使使用对话ID，仍然进行检查，确保最高质量）
      if (previousChapters.isNotEmpty) {
        onProgress?.call('正在检查内容连贯性...');
        cleanedContent = await _ensureChapterCoherence(
          generatedContent: cleanedContent, 
          previousChapters: previousChapters,
          outline: outline,
          chapterNumber: number,
          onProgress: onProgress,
        );
      }
      
      onProgress?.call('第$number章生成完成');
      
      return Chapter(
        number: number,
        title: _extractChapterTitle(cleanedContent, number),
        content: cleanedContent,
      );
    } catch (e) {
      print('生成章节内容失败: $e');
      throw Exception('生成章节内容失败: $e');
    }
  }

  double _getTemperatureForChapter(int number, int totalChapters) {
    final progress = number / totalChapters;
    if (progress < 0.2) return 0.8;  // 提高开始阶段的创造性
    if (progress < 0.4) return 0.85;
    if (progress < 0.7) return 0.9;
    return 0.85;  // 提高结尾阶段的创造性
  }

  // 根据章节位置返回不同的最大token数，确保足够容纳前文信息
  int _getMaxTokensForChapter(int chapterNumber) {
    // 基础token数
    int baseTokens = 3000;
    
    // 根据章节数增加token，越往后，需要的前文越多
    int additionalTokens = (chapterNumber - 1) * 200;
    
    // 设置上限，避免超出模型限制
    int maxAdditionalTokens = 4000;  // 增加到5000，以容纳更多前文
    
    // 最终的token数
    return baseTokens + (additionalTokens > maxAdditionalTokens ? maxAdditionalTokens : additionalTokens);
  }

  String _getChapterStyle(int number, int totalChapters) {
    final styles = [
      '细腻写实',
      '跌宕起伏',
      '悬疑迷离',
      '热血激昂',
      '温情脉脉',
      '峰回路转',
      '诙谐幽默',
      '沉稳大气',
      '清新淡雅',
      '惊心动魄'
    ];
    return styles[number % styles.length];
  }

  String _getChapterFocus(int number, int totalChapters) {
    final focuses = [
      '人物内心活动',
      '场景氛围营造',
      '动作场面',
      '对话交锋',
      '环境描写',
      '情感纠葛',
      '矛盾冲突',
      '人物关系',
      '社会背景',
      '心理变化'
    ];
    return focuses[number % focuses.length];
  }

  String _getChapterTechnique(int number, int totalChapters) {
    final techniques = [
      '倒叙插叙',
      '多线并进',
      '意识流',
      '象征暗示',
      '悬念设置',
      '细节刻画',
      '场景切换',
      '心理描写',
      '对比反衬',
      '首尾呼应'
    ];
    return techniques[number % techniques.length];
  }

  String _getNarrationStyle(int number, int totalChapters) {
    final styles = [
      '全知视角',
      '第一人称',
      '限制视角',
      '多视角交替',
      '客观视角',
      '意识流',
      '书信体',
      '日记体',
      '倒叙',
      '插叙'
    ];
    return styles[number % styles.length];
  }

  String _getDescriptionStyle(int number, int totalChapters) {
    final styles = [
      '白描手法',
      '细节刻画',
      '心理描写',
      '环境烘托',
      '动作描写',
      '对话刻画',
      '象征手法',
      '比喻修辞',
      '夸张手法',
      '衬托对比'
    ];
    return styles[number % styles.length];
  }

  String _getPlotDevice(int number, int totalChapters) {
    final devices = [
      '悬念',
      '伏笔',
      '巧合',
      '误会',
      '反转',
      '暗示',
      '象征',
      '对比',
      '平行',
      '递进'
    ];
    return devices[number % devices.length];
  }

  String _getChapterRhythm(int number, int totalChapters) {
    final rhythms = [
      '舒缓绵长',
      '紧凑快节奏',
      '起伏跌宕',
      '徐徐展开',
      '波澜起伏',
      '节奏明快',
      '张弛有度',
      '缓急结合',
      '循序渐进',
      '高潮迭起'
    ];
    return rhythms[number % rhythms.length];
  }

  String _getEmotionalStyle(int number, int totalChapters) {
    final styles = [
      '情绪爆发',
      '含蓄委婉',
      '峰回路转',
      '悬念迭起',
      '温情脉脉',
      '激烈冲突',
      '平淡中见真情',
      '跌宕起伏',
      '意味深长',
      '震撼人心'
    ];
    return styles[number % styles.length];
  }

  String _getEndingStyle(int number, int totalChapters) {
    final styles = [
      '悬念收尾',
      '意味深长',
      '余音绕梁',
      '峰回路转',
      '留白处理',
      '首尾呼应',
      '点题升华',
      '情感升华',
      '引人深思',
      '伏笔埋藏'
    ];
    return styles[number % styles.length];
  }

  String _determineStyle(int currentChapter, int totalChapters, String? userStyle) {
    // 如果用户指定了风格，优先使用
    if (userStyle != null && userStyle.isNotEmpty) {
      return userStyle;
    }
    
    // 否则使用默认逻辑
    final progress = currentChapter / totalChapters;
    if (progress < 0.3) {
      return '轻松爽快';
    } else if (progress < 0.7) {
      return '热血激昂';
    } else {
      return '高潮迭起';
    }
  }

  String _generateChapterSummary(String content) {
    // 简单地截取内容的前三分之一作为摘要
    final lines = content.split('\n');
    final startIndex = (lines.length * 2 / 3).round();
    return lines.sublist(startIndex).join('\n');
  }

  String _designChapterFocus({
    required int number,
    required int totalChapters,
    required String outline,
  }) {
    final progress = number / totalChapters;
    final buffer = StringBuffer();

    buffer.writeln('本章创作指导：');
    
    // 基础结构指导
    buffer.writeln('【结构创新】');
    if (number == 1) {
      buffer.writeln('- 尝试以非常规视角或时间点切入');
      buffer.writeln('- 通过细节和氛围暗示而不是直接介绍');
      buffer.writeln('- 设置悬念，但不要过于明显');
    } else {
      buffer.writeln('- 避免线性叙事，可以穿插回忆或预示');
      buffer.writeln('- 通过多线并进推进剧情');
      buffer.writeln('- 在关键处设置情节反转或悬念');
    }

    // 场景设计指导
    buffer.writeln('\n【场景设计】');
    buffer.writeln('- 融入独特的环境元素和氛围');
    buffer.writeln('- 通过环境暗示人物心理变化');
    buffer.writeln('- 注重细节描写的新颖性');

    // 人物互动指导
    buffer.writeln('\n【人物刻画】');
    buffer.writeln('- 展现人物的矛盾性和复杂性');
    buffer.writeln('- 通过细微互动体现性格特点');
    buffer.writeln('- 设置内心独白或心理活动');

    // 根据进度添加特殊要求
    buffer.writeln('\n【阶段重点】');
    if (progress < 0.2) {
      buffer.writeln('起始阶段：');
      buffer.writeln('- 设置伏笔但不要太明显');
      buffer.writeln('- 展现人物性格的多面性');
      buffer.writeln('- 通过细节暗示未来发展');
    } else if (progress < 0.4) {
      buffer.writeln('发展初期：');
      buffer.writeln('- 制造情节小高潮');
      buffer.writeln('- 加入意外事件或转折');
      buffer.writeln('- 深化人物关系发展');
    } else if (progress < 0.6) {
      buffer.writeln('中期发展：');
      buffer.writeln('- 展开多线叙事');
      buffer.writeln('- 设置次要矛盾冲突');
      buffer.writeln('- 暗示重要转折点');
    } else if (progress < 0.8) {
      buffer.writeln('高潮铺垫：');
      buffer.writeln('- 多线交织推进');
      buffer.writeln('- 设置关键抉择');
      buffer.writeln('- 情节反转或悬念');
    } else {
      buffer.writeln('结局阶段：');
      buffer.writeln('- 出人意料的结局');
      buffer.writeln('- 首尾呼应但不落俗套');
      buffer.writeln('- 留有想象空间');
    }

    // 写作技巧指导
    buffer.writeln('\n【创新要求】');
    buffer.writeln('1. 叙事视角：');
    buffer.writeln('   - 尝试不同视角切换');
    buffer.writeln('   - 运用时空交错手法');
    buffer.writeln('   - 适当使用意识流');

    buffer.writeln('2. 情节设计：');
    buffer.writeln('   - 避免套路化发展');
    buffer.writeln('   - 设置合理反转');
    buffer.writeln('   - 保持悬念感');

    buffer.writeln('3. 细节描写：');
    buffer.writeln('   - 独特的比喻和修辞');
    buffer.writeln('   - 新颖的场景描绘');
    buffer.writeln('   - 富有特色的对话');

    return buffer.toString();
  }

  String _getChapterSummary(String content) {
    // 取最后三分之一的内容作为上下文
    final lines = content.split('\n');
    final startIndex = (lines.length * 2 / 3).round();
    return lines.sublist(startIndex).join('\n');
  }

  Future<Novel> generateNovel({
    required String title,
    required List<String> genres,
    required String background,
    required String otherRequirements,
    required Function(String) updateRealtimeOutput,
    required Function(String) updateGenerationStatus,
    required Function(double) updateGenerationProgress,
    required String style,
    required String targetReader,
    int totalChapters = 5,
    bool continueGeneration = false,
    bool useOutline = false,
    NovelOutline? outline,
    List<Chapter>? previousChapters,
    required bool isShortNovel,
    int wordCount = 15000,
    Function(Novel)? onNovelCreated,
    Map<String, CharacterCard>? characterCards,
    List<CharacterType>? characterTypes,
  }) async {
    _updateRealtimeOutput = updateRealtimeOutput;
    _updateGenerationStatus = updateGenerationStatus;
    _updateGenerationProgress = updateGenerationProgress;
    
    // 记录开始时间
    final startTime = DateTime.now();
    
    if (isShortNovel) {
      // 确保短篇小说大纲正确显示
      updateGenerationStatus('正在生成短篇小说大纲...');
      updateRealtimeOutput('开始生成短篇小说大纲...\n');
      
      // 生成短篇小说大纲
      final shortNovelOutline = await _generateShortNovelOutline(
            title: title,
        genres: genres,
            background: background,
        otherRequirements: otherRequirements,
            style: style,
        targetReader: targetReader,
        characterCards: characterCards,
        characterTypes: characterTypes,
      );
      
      // 显示大纲信息
      updateRealtimeOutput('\n========== 短篇小说大纲 ==========\n');
      updateRealtimeOutput(shortNovelOutline);
      updateRealtimeOutput('\n================================\n\n');
      
      // 生成短篇小说内容
      updateGenerationStatus('正在生成短篇小说内容...');
      updateRealtimeOutput('开始生成短篇小说内容...\n');
      
      // 确保生成到指定字数
      final shortNovelContent = await _generateShortNovelContent(
          title: title,
          genres: genres,
        background: background,
        otherRequirements: otherRequirements,
          style: style,
          targetReader: targetReader,
        outline: shortNovelOutline,
        targetWordCount: wordCount, // 使用用户设定的字数
          characterCards: characterCards,
          characterTypes: characterTypes,
      );
      
      updateGenerationStatus('短篇小说生成完成！');
      final novel = Novel(
        title: title,
        genre: genres.join(','),
        outline: shortNovelOutline,
        content: shortNovelContent,
        chapters: [
          Chapter(
            number: 1,
            title: title,
            content: shortNovelContent,
          )
        ],
        createdAt: DateTime.now(),
      );
      
      // 记录完成时间并计算耗时
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      
      updateRealtimeOutput('\n短篇小说生成完成！耗时：$minutes分$seconds秒\n');
      updateRealtimeOutput('小说总字数：${shortNovelContent.length}字\n');
      
      if (onNovelCreated != null) {
        onNovelCreated(novel);
      }
      
      return novel;
    } else {
      // 长篇小说生成逻辑
      Novel novel = Novel(
        title: title,
        genre: genres.join(','),
        outline: '',
        content: '',
        chapters: [],
        createdAt: DateTime.now(),
      );
      
      try {
        // 检查是否继续生成
        if (continueGeneration && previousChapters != null && previousChapters.isNotEmpty) {
          updateGenerationStatus('正在从上次进度继续生成...');
          updateRealtimeOutput('继续生成小说，从第${previousChapters.length + 1}章开始...\n');
          
          // 设置初始章节
          novel = novel.copyWith(chapters: List.from(previousChapters));
          
          // 如果有大纲，使用现有大纲
          if (useOutline && outline != null) {
            novel = novel.copyWith(outline: outline.toString());
          }
        } else {
          // 新生成小说
          updateGenerationStatus('正在生成大纲...');
          updateRealtimeOutput('开始生成小说大纲...\n');
          
          // 生成大纲
          String outlineContent;
          if (useOutline && outline != null) {
            // 使用用户提供的大纲
            outlineContent = outline.toString();
            updateRealtimeOutput('使用用户提供的大纲：\n$outlineContent\n');
            
            // 确保大纲内容被正确处理
            if (outline is NovelOutline) {
              // 如果是NovelOutline对象，转换为JSON字符串以便更好地提取章节信息
              try {
                final outlineJson = jsonEncode({
                  'novel_title': outline.novelTitle,
                  'chapters': outline.chapters.map((ch) => {
                    'chapter_number': ch.chapterNumber,
                    'chapter_title': ch.chapterTitle,
                    'content_outline': ch.contentOutline
                  }).toList()
                });
                outlineContent = outlineJson;
                print('将NovelOutline对象转换为JSON格式');
              } catch (e) {
                print('转换NovelOutline为JSON失败: $e');
              }
            }
          } else {
            // 生成新大纲
            outlineContent = await generateOutline(
              title: title,
              genre: genres.join(','),
              theme: background,
              targetReaders: targetReader,
              totalChapters: totalChapters,
              onProgress: (status) => updateGenerationStatus(status),
              onContent: (content) => updateRealtimeOutput(content),
              characterCards: characterCards,
              characterTypes: characterTypes,
            );
          }
          
          novel = novel.copyWith(outline: outlineContent);
          
          // 显示大纲信息
          updateRealtimeOutput('\n========== 小说大纲 ==========\n');
          updateRealtimeOutput(outlineContent);
          updateRealtimeOutput('\n================================\n\n');
        }
        
        // 生成章节内容
        updateGenerationStatus('正在生成章节内容...');
        
        // 计算起始章节
        int startChapter = continueGeneration && previousChapters != null ? previousChapters.length + 1 : 1;
        
        // 生成每个章节
        for (int i = startChapter; i <= totalChapters; i++) {
          // 检查是否暂停
          await _checkPause();
          
          // 更新进度
          final progress = (i - startChapter) / (totalChapters - startChapter + 1);
          updateGenerationProgress(progress);
          updateGenerationStatus('正在生成第$i章 (${(progress * 100).toStringAsFixed(1)}%)');
          updateRealtimeOutput('\n正在生成第$i章...\n');
          
          // 生成章节内容
          final chapterContent = await _generateChapter(
            title: title,
            genre: genres.join(','),
            theme: background,
            outline: novel.outline,
            chapterNumber: i,
            totalChapters: totalChapters,
            previousChapters: novel.chapters,
            onContent: (content) => updateRealtimeOutput(content),
            characterCards: characterCards,
            characterTypes: characterTypes,
          );
          
          // 提取章节标题
          final chapterTitle = _extractChapterTitle(chapterContent, i) ?? '第$i章';
          
          // 创建章节对象
          final chapter = Chapter(
            number: i,
            title: chapterTitle,
            content: chapterContent,
          );
          
          // 添加到小说中
          novel.chapters.add(chapter);
          
          // 更新小说内容
          novel = novel.copyWith(content: novel.chapters.map((c) => c.content).join('\n\n'));
          
          // 保存当前进度
          await _saveGenerationProgress(
            title: title,
            genre: genres.join(','),
            theme: background,
            targetReaders: targetReader,
            totalChapters: totalChapters,
            outline: novel.outline,
            chapters: novel.chapters,
          );
          
          // 通知回调
          if (onNovelCreated != null) {
            onNovelCreated(novel);
          }
        }
        
        // 生成完成
        updateGenerationStatus('小说生成完成！');
        updateGenerationProgress(1.0);
        
        // 记录完成时间并计算耗时
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        
        updateRealtimeOutput('\n小说生成完成！耗时：$minutes分$seconds秒\n');
        updateRealtimeOutput('小说总字数：${novel.content.length}字\n');
        
        // 清除生成进度
        await clearGenerationProgress();
        
        return novel;
      } catch (e) {
        print('生成小说失败: $e');
        
        if ('$e'.contains('暂停')) {
          // 如果是用户主动暂停，保存当前进度
          await _saveGenerationProgress(
            title: title,
            genre: genres.join(','),
            theme: background,
            targetReaders: targetReader,
            totalChapters: totalChapters,
            outline: novel.outline,
            chapters: novel.chapters,
          );
        }
        
        rethrow;
      }
    }
  }

  // 添加短篇小说大纲生成方法
  Future<String> _generateShortNovelOutline({
    required String title,
    required List<String> genres,
    required String background,
    required String otherRequirements,
    required String style,
    required String targetReader,
    Map<String, CharacterCard>? characterCards,
    List<CharacterType>? characterTypes,
  }) async {
    try {
      // 构建包含角色信息的提示词
      String characterPrompt = '';
      if (characterCards != null && characterCards.isNotEmpty && characterTypes != null) {
        characterPrompt = '小说角色设定：\n';
        for (final type in characterTypes) {
          final card = characterCards[type.id];
          if (card != null) {
            characterPrompt += '${type.name}：${card.name}\n';
            if (card.gender != null && card.gender!.isNotEmpty) {
              characterPrompt += '性别：${card.gender}\n';
            }
            if (card.age != null && card.age!.isNotEmpty) {
              characterPrompt += '年龄：${card.age}\n';
            }
            if (card.personalityTraits != null && card.personalityTraits!.isNotEmpty) {
              characterPrompt += '性格：${card.personalityTraits}\n';
            }
            if (card.background != null && card.background!.isNotEmpty) {
              characterPrompt += '背景：${card.background}\n';
            }
            characterPrompt += '\n';
          }
        }
      }

      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final shortNovelPrompt = promptPackageController.getShortNovelPromptContent('short_novel', targetReader);
      
      // 根据目标读者选择不同的提示词
      String outlineFormatPrompt;
      String genre = genres.isNotEmpty ? genres.join('、') : '通用';
      
      if (targetReader == '女性向') {
        // 使用新的女性向短篇提示词
        outlineFormatPrompt = ShortNovelFemalePrompts.getShortNovelOutlinePrompt(title, genre, otherRequirements, 15000);
      } else {
        // 使用新的男性向短篇提示词
        outlineFormatPrompt = ShortNovelMalePrompts.getShortNovelOutlinePrompt(title, genre, otherRequirements, 15000);
      }
      
      // 获取特定角色提示词
      String characterDesignPrompt = '';
      if (targetReader == '女性向') {
        characterDesignPrompt = ShortNovelFemalePrompts.getCharacterPrompt();
      } else {
        characterDesignPrompt = ShortNovelMalePrompts.getCharacterPrompt();
      }
      
      // 构建完整提示词
      final prompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${shortNovelPrompt.isNotEmpty ? shortNovelPrompt + '\n\n' : ''}

你是一位优秀的小说创作者，请根据以下要求创作一部短篇小说的详细大纲：

小说标题：$title
小说类型：${genres.join('，')}
目标读者：$targetReader
写作风格：$style
${background.isNotEmpty ? '背景设定：$background\n' : ''}
${otherRequirements.isNotEmpty ? '其他要求：$otherRequirements\n' : ''}
$characterPrompt

$characterDesignPrompt

$outlineFormatPrompt

请直接生成大纲内容，不需要包含解释或说明。
''';

      // 调用AI服务生成大纲
      return await _aiService.generateShortNovelOutline(prompt);
    } catch (e) {
      _updateProgress("大纲生成失败: $e");
      rethrow;
    }
  }

  // 生成短篇小说内容
  Future<String> _generateShortNovelContent({
    required String title,
    required List<String> genres,
    required String background,
    required String otherRequirements,
    required String style,
    required String targetReader,
    required String outline,
    required int targetWordCount,
    Map<String, CharacterCard>? characterCards,
    List<CharacterType>? characterTypes,
  }) async {
    // 构建包含角色信息的提示词
    String characterPrompt = '';
    if (characterCards != null && characterCards.isNotEmpty && characterTypes != null) {
      characterPrompt = '小说角色设定：\n';
      for (final type in characterTypes) {
        final card = characterCards[type.id];
        if (card != null) {
          characterPrompt += '${type.name}：${card.name}\n';
          if (card.gender != null && card.gender!.isNotEmpty) {
            characterPrompt += '性别：${card.gender}\n';
          }
          if (card.age != null && card.age!.isNotEmpty) {
            characterPrompt += '年龄：${card.age}\n';
          }
          if (card.personalityTraits != null && card.personalityTraits!.isNotEmpty) {
            characterPrompt += '性格：${card.personalityTraits}\n';
          }
          if (card.background != null && card.background!.isNotEmpty) {
            characterPrompt += '背景：${card.background}\n';
          }
          characterPrompt += '\n';
        }
      }
    }

    // 获取提示词包内容
    final promptPackageController = Get.find<PromptPackageController>();
    final masterPrompt = promptPackageController.getCurrentPromptContent('master');
    final shortNovelPrompt = promptPackageController.getShortNovelPromptContent('short_novel', targetReader);

    // 首先生成完整结构的框架，确保五部分完整分布
    final initialOutlinePrompt = '''
你是一位出色的故事策划者，请根据以下信息创建一个详细的五段式故事结构框架：

小说标题：$title
小说类型：${genres.join('，')}
目标读者：$targetReader
写作风格：$style
${background.isNotEmpty ? '背景设定：$background\n' : ''}
${otherRequirements.isNotEmpty ? '其他要求：$otherRequirements\n' : ''}
$characterPrompt

用户提供的大纲：
$outline

请创建一个详细的五段式故事框架，包括以下五个部分：
1. 开篇与背景铺垫（约占15%）
2. 冲突展开（约占20%）
3. 情节发展与转折（约占30%）
4. 高潮与危机（约占20%）
5. 结局与收尾（约占15%）

每个部分需要包含：
- 该部分的核心情节发展
- 重要场景设置
- 角色互动重点
- 情感和气氛的变化
- 与前后部分的自然衔接点

请确保框架的连贯性和完整性，为后续内容创作提供明确指导。
''';

    // 生成大纲框架
    _updateRealtimeOutput("正在规划故事结构...\n");
    final outlineFramework = await _aiService.generateShortNovelContent(initialOutlinePrompt);
    
    // 将大纲框架分成五个部分
    final outlineParts = _divideOutlineIntoFiveParts(outlineFramework);
    if (outlineParts.length != 5) {
      _updateRealtimeOutput("\n故事结构划分不正确，重新调整...\n");
      return await _generateShortNovelContent(
        title: title,
        genres: genres,
        background: background,
        otherRequirements: otherRequirements,
        style: style,
        targetReader: targetReader,
        outline: outline,
        targetWordCount: targetWordCount,
        characterCards: characterCards,
        characterTypes: characterTypes,
      );
    }
    
    // 计算每个部分的目标字数
    final partWordCounts = [
      (targetWordCount * 0.15).round(), // 开篇与背景铺垫
      (targetWordCount * 0.20).round(), // 冲突展开
      (targetWordCount * 0.30).round(), // 情节发展与转折
      (targetWordCount * 0.20).round(), // 高潮与危机
      (targetWordCount * 0.15).round(), // 结局与收尾
    ];
    
    // 依次生成每个部分的内容
    String fullContent = '';
    
    for (int i = 0; i < 5; i++) {
      final partTitle = _getPartTitle(i);
      _updateRealtimeOutput("\n正在创作 ${i+1}/5：$partTitle...\n");
      
      // 构建连续性上下文
      String continuityContext = '';
      
      if (i > 0) {
        // 如果不是第一部分，提供前文内容摘要
        final previousContent = fullContent.length > 500 
          ? fullContent.substring(fullContent.length - 500) + '...' 
          : fullContent;
        
        continuityContext = '''
前文内容概要：
${previousContent.isNotEmpty ? previousContent : "故事尚未开始"}

前一部分（${_getPartTitle(i-1)}）的结尾内容：
${fullContent.isNotEmpty ? (fullContent.length > 300 ? fullContent.substring(fullContent.length - 300) : fullContent) : "故事尚未开始"}

请确保本部分与前文的自然衔接。
''';
      }
      
      if (i < 4) {
        // 如果不是最后部分，提供下一部分的预期走向
        continuityContext += '''
下一部分（${_getPartTitle(i+1)}）的内容概要：
${outlineParts[i+1].length > 300 ? outlineParts[i+1].substring(0, 300) + '...' : outlineParts[i+1]}

请确保本部分结尾能够自然引导至下一部分的开始。
''';
      }
      
      // 构建部分提示词
      String partPrompt;
      String genre = genres.isNotEmpty ? genres.join('，') : '通用';
      bool isFirstPart = (i == 0);
      bool isLastPart = (i == 4);
      
      if (targetReader == '女性向') {
        partPrompt = ShortNovelFemalePrompts.getShortNovelPartPrompt(
          title,
          genre,
          partTitle,
          outlineParts[i],
          i > 0 ? fullContent.substring(math.max(0, fullContent.length - 500)) : "",
          i < 4 ? outlineParts[i+1] : "",
          partWordCounts[i],
          isFirstPart,
          isLastPart
        );
      } else {
        partPrompt = ShortNovelMalePrompts.getShortNovelPartPrompt(
          title,
          genre,
          partTitle,
          outlineParts[i],
          i > 0 ? fullContent.substring(math.max(0, fullContent.length - 500)) : "",
          i < 4 ? outlineParts[i+1] : "",
          partWordCounts[i],
          isFirstPart,
          isLastPart
        );
      }
      
      // 完整的部分生成提示词
      final fullPartPrompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${shortNovelPrompt.isNotEmpty ? shortNovelPrompt + '\n\n' : ''}

$partPrompt
''';
      
      // 生成这部分的内容
      final partContent = await _aiService.generateShortNovelContent(fullPartPrompt);
      
      // 添加到完整内容中
      if (i > 0) {
        fullContent += "\n\n" + partContent;
      } else {
        fullContent = partContent;
      }
      
      // 更新进度
      _updateProgress("正在创作 ${i+1}/5：$partTitle");
    }
    
    // 检查最终字数
    final currentWordCount = fullContent.length;
    _updateRealtimeOutput("\n内容生成完成，当前字数：$currentWordCount\n");
    
    if (currentWordCount < targetWordCount * 0.9) {
      _updateRealtimeOutput("字数不足目标（$targetWordCount），正在增强内容...\n");
      fullContent = await _enhanceContentToMeetWordCount(
        fullContent, 
        targetWordCount,
        title,
        style
      );
    }
    
    return fullContent;
  }

  // 新增：判断两段内容是否需要过渡段落
  bool _needsTransition(String firstContent, String secondContent) {
    // 提取第一段内容的最后一个段落
    final lastParagraph = _getLastParagraph(firstContent);
    
    // 提取第二段内容的第一个段落
    final firstParagraph = _getFirstParagraph(secondContent);
    
    // 检查时间连续性
    final timeJumpIndicators = ['第二天', '一周后', '几天后', '几个月后', '几年后', '转眼'];
    for (final indicator in timeJumpIndicators) {
      if (firstParagraph.contains(indicator)) {
        return false; // 已有明确的时间转换，不需要额外过渡
      }
    }
    
    // 检查场景转换
    if (lastParagraph.contains('离开') || lastParagraph.contains('走出') || 
        lastParagraph.contains('告别') || lastParagraph.contains('结束')) {
      return true; // 可能需要场景转换过渡
    }
    
    // 检查人物变化
    final lastCharacters = _extractCharacters(lastParagraph);
    final firstCharacters = _extractCharacters(firstParagraph);
    
    // 如果主要人物完全不同，可能需要过渡
    if (lastCharacters.isNotEmpty && firstCharacters.isNotEmpty && 
        !lastCharacters.any((c) => firstCharacters.contains(c))) {
      return true;
    }
    
    // 默认判断:如果结尾和开头都是对话或都不是对话，可能更自然
    final lastIsDialogue = lastParagraph.trim().startsWith('"') || lastParagraph.trim().startsWith('"');
    final firstIsDialogue = firstParagraph.trim().startsWith('"') || firstParagraph.trim().startsWith('"');
    
    return lastIsDialogue != firstIsDialogue;
  }
  
  // 新增：多层次内容扩充策略
  Future<String> _enhanceContentWithMultiLevelStrategy(
    String content, 
    int targetWordCount,
    String title,
    String style,
    List<String> outlineParts
  ) async {
    // 当前字数
    final currentWordCount = content.length;
    final neededWords = targetWordCount - currentWordCount;
    
    // 如果差距相对较小，使用整体扩充
    if (neededWords < targetWordCount * 0.15) {
      return await _enhanceContentToMeetWordCount(
        content, 
        targetWordCount,
        title,
        style
      );
    }
    
    // 将内容分成五个部分进行针对性扩充
    final contentParts = _divideContentIntoFiveParts(content);
    
    // 检查每个部分的长度与目标比例
    final idealPartSizes = [
      targetWordCount * 0.18, // 第一部分 18%
      targetWordCount * 0.22, // 第二部分 22%
      targetWordCount * 0.28, // 第三部分 28%
      targetWordCount * 0.22, // 第四部分 22%
      targetWordCount * 0.10, // 第五部分 10%
    ];
    
    // 找出差距最大的部分优先扩充
    List<int> expansionPriority = List.generate(5, (i) => i);
    expansionPriority.sort((a, b) {
      final gapA = idealPartSizes[a] - contentParts[a].length;
      final gapB = idealPartSizes[b] - contentParts[b].length;
      return gapB.compareTo(gapA); // 降序排列
    });
    
    String enhancedContent = '';
    
    // 按优先级扩充内容
    for (int partIndex in expansionPriority) {
      if (enhancedContent.length >= targetWordCount) break;
      
      final partTitle = _getPartTitle(partIndex);
      final partOutline = outlineParts[partIndex];
      final currentPart = contentParts[partIndex];
      final targetPartSize = idealPartSizes[partIndex].round();
      
      // 如果这部分明显偏短，进行重点扩充
      if (currentPart.length < targetPartSize * 0.8) {
        _updateRealtimeOutput("\n第${partIndex+1}部分（$partTitle）明显偏短，进行重点扩充...\n");
        
        // 计算前后文上下文
        String previousContext = '';
        String nextContext = '';
        
        if (partIndex > 0) {
          previousContext = _getLastParagraph(
            partIndex > 0 ? contentParts[partIndex - 1] : '', 
            3
          );
        }
        
        if (partIndex < 4) {
          nextContext = _getFirstParagraph(
            partIndex < 4 ? contentParts[partIndex + 1] : '',
            3
          );
        }
        
        // 区域扩充提示词
        final partEnhancePrompt = '''
请对短篇小说"$title"的第${partIndex+1}部分（$partTitle）进行有针对性的扩充和丰富，使这部分从当前的${currentPart.length}字增加到约${targetPartSize}字：

原有内容：
$currentPart

${previousContext.isNotEmpty ? '前文末尾：\n$previousContext\n' : ''}
${nextContext.isNotEmpty ? '后文开头：\n$nextContext\n' : ''}

该部分应该包含的要点（来自大纲）：
$partOutline

扩充要求：
1. 保持与原有情节的连贯性，同时丰富细节和深度
2. 增加该部分特有的情感变化和情节深化
3. 增强人物形象塑造和互动场景
4. 保持"$style"的写作风格
5. 确保与前后文的自然衔接
6. ${partIndex == 0 ? '强化开篇的吸引力和情境构建' : 
     partIndex == 4 ? '完善结局，确保故事有合理完整的收束' :
     partIndex == 2 ? '加强情节转折的戏剧性和深度' :
     '丰富情节和冲突，增强读者代入感'}

请返回完整扩充后的这部分内容：
''';

        final enhancedPart = await _aiService.generateShortNovelContent(partEnhancePrompt);
        
        // 替换到原内容中
        contentParts[partIndex] = enhancedPart;
      }
    }
    
    // 重新组合完整内容
    enhancedContent = contentParts.join("\n\n");
    
    // 如果字数仍然不足，进行第二轮一般性扩充
    if (enhancedContent.length < targetWordCount * 0.9) {
      _updateRealtimeOutput("\n经过重点扩充后字数仍不足，进行整体增强...\n");
      enhancedContent = await _enhanceContentToMeetWordCount(
        enhancedContent, 
        targetWordCount,
        title,
        style
      );
    }
    
    return enhancedContent;
  }
  
  // 新增：将内容分成五个部分
  List<String> _divideContentIntoFiveParts(String content) {
    final List<String> result = List.filled(5, '');
    
    // 尝试通过部分标题定位
    final partTitles = [
      "开篇与背景铺垫", "冲突展开", "情节发展与转折", "高潮与危机", "结局与收尾"
    ];
    
    final Map<String, int> titlePositions = {};
    
    // 寻找标题位置
    for (int i = 0; i < partTitles.length; i++) {
      final title = partTitles[i];
      int position = content.indexOf(title);
      
      // 如果找不到完整标题，尝试简化版本
      if (position < 0) {
        position = content.indexOf(title.replaceAll("与", ""));
      }
      
      if (position >= 0) {
        titlePositions[title] = position;
      }
    }
    
    // 如果找到至少两个标题位置，可以进行划分
    if (titlePositions.length >= 2) {
      final sortedPositions = titlePositions.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // 划分内容
      for (int i = 0; i < sortedPositions.length; i++) {
        final startPos = sortedPositions[i].value;
        final endPos = i < sortedPositions.length - 1 ? 
                      sortedPositions[i + 1].value : 
                      content.length;
        
        // 找到对应的部分索引
        final titleIndex = partTitles.indexOf(sortedPositions[i].key);
        if (titleIndex >= 0) {
          result[titleIndex] = content.substring(startPos, endPos).trim();
        }
      }
      
      // 填充未找到的部分
      for (int i = 0; i < result.length; i++) {
        if (result[i].isEmpty && i > 0 && i < result.length - 1) {
          // 如果中间部分缺失，尝试从前后推断
          int prevFoundIndex = i - 1;
          while (prevFoundIndex >= 0 && result[prevFoundIndex].isEmpty) {
            prevFoundIndex--;
          }
          
          int nextFoundIndex = i + 1;
          while (nextFoundIndex < result.length && result[nextFoundIndex].isEmpty) {
            nextFoundIndex++;
          }
          
          if (prevFoundIndex >= 0 && nextFoundIndex < result.length) {
            // 找到前后都有内容的部分，按比例分配中间区域
            // 这里简化处理，实际应用可能需要更复杂的逻辑
            result[i] = "该部分内容与其他部分混合，无法清晰区分";
          }
        }
      }
      
      return result;
    }
    
    // 回退策略：如果无法通过标题划分，按段落比例划分
    final paragraphs = content.split('\n\n');
    
    if (paragraphs.length >= 5) {
      final segmentLengths = [
        (paragraphs.length * 0.18).ceil(),
        (paragraphs.length * 0.22).ceil(),
        (paragraphs.length * 0.28).ceil(),
        (paragraphs.length * 0.22).ceil(),
        paragraphs.length - 
          (paragraphs.length * 0.18).ceil() - 
          (paragraphs.length * 0.22).ceil() - 
          (paragraphs.length * 0.28).ceil() - 
          (paragraphs.length * 0.22).ceil()
      ];
      
      int currentIndex = 0;
      for (int i = 0; i < 5; i++) {
        final endIndex = math.min(currentIndex + segmentLengths[i], paragraphs.length);
        result[i] = paragraphs.sublist(currentIndex, endIndex).join('\n\n');
        currentIndex = endIndex;
      }
      
      return result;
    }
    
    // 最后的回退：简单平均分配
    final charPerPart = content.length ~/ 5;
    for (int i = 0; i < 5; i++) {
      final startPos = i * charPerPart;
      final endPos = i < 4 ? (i + 1) * charPerPart : content.length;
      
      if (startPos < content.length) {
        result[i] = content.substring(startPos, math.min(endPos, content.length));
      }
    }
    
    return result;
  }
  
  // 辅助方法：提取段落中的人物
  List<String> _extractCharacters(String paragraph) {
    final List<String> characters = [];
    final namePattern = RegExp(r'([A-Z][a-z]+|[\u4e00-\u9fa5]{1,3})(?=说道|回答|问道|喊道|叹道|笑道|看着|走向|站在|坐在|对|和|与|、)');
    
    for (final match in namePattern.allMatches(paragraph)) {
      final name = match.group(1);
      if (name != null && name.length >= 1 && !characters.contains(name)) {
        characters.add(name);
      }
    }
    
    return characters;
  }
  
  // 辅助方法：获取内容的最后几个段落
  String _getLastParagraph(String content, [int paragraphCount = 1]) {
    if (content.isEmpty) return '';
    
    final paragraphs = content.split('\n\n');
    if (paragraphs.isEmpty) return '';
    
    final count = math.min(paragraphCount, paragraphs.length);
    return paragraphs.sublist(paragraphs.length - count).join('\n\n');
  }
  
  // 辅助方法：获取内容的前几个段落
  String _getFirstParagraph(String content, [int paragraphCount = 1]) {
    if (content.isEmpty) return '';
    
    final paragraphs = content.split('\n\n');
    if (paragraphs.isEmpty) return '';
    
    final count = math.min(paragraphCount, paragraphs.length);
    return paragraphs.take(count).join('\n\n');
  }
  
  // 辅助方法：生成内容摘要
  String _generateContentSummary(String content, int maxLength) {
    if (content.length <= maxLength) return content;
    
    // 简单方法：提取关键段落
    final paragraphs = content.split('\n\n');
    
    // 如果段落较少，直接取前几段
    if (paragraphs.length <= 5) {
      String summary = paragraphs.take(3).join('\n\n');
      if (summary.length > maxLength) {
        summary = summary.substring(0, maxLength) + '...';
      }
      return summary;
    }
    
    // 尝试提取更有代表性的段落：开头、结尾和中间的一段
    String summary = paragraphs.first + '\n\n' +
                    paragraphs[paragraphs.length ~/ 2] + '\n\n' +
                    paragraphs.last;
    
    if (summary.length > maxLength) {
      summary = summary.substring(0, maxLength) + '...';
    }
    
    return summary;
  }

  // 解析五段式大纲，返回五个部分的内容
  List<String> _parseFivePartOutline(String outline) {
    List<String> parts = [];
    
    // 尝试按"第X部分"或"X部分"或"第X部分 - "等格式分割大纲
    final partPatterns = [
      RegExp(r'第一部分[\s\-：:]*.*?(?=第二部分|$)', dotAll: true),
      RegExp(r'第二部分[\s\-：:]*.*?(?=第三部分|$)', dotAll: true),
      RegExp(r'第三部分[\s\-：:]*.*?(?=第四部分|$)', dotAll: true),
      RegExp(r'第四部分[\s\-：:]*.*?(?=第五部分|$)', dotAll: true),
      RegExp(r'第五部分[\s\-：:]*.*', dotAll: true),
    ];
    
    for (var pattern in partPatterns) {
      final match = pattern.firstMatch(outline);
      if (match != null) {
        var part = match.group(0) ?? '';
        // 清理部分标题，只保留内容
        part = part.replaceFirst(RegExp(r'^第[一二三四五]部分[\s\-：:]*[^\n]*\n'), '').trim();
        parts.add(part);
      } else {
        // 如果找不到匹配，添加空字符串作为占位符
        parts.add('');
      }
    }
    
    // 如果解析失败（有空部分），尝试按比例等分大纲
    if (parts.contains('')) {
      parts = [];
      final lines = outline.split('\n');
      
      // 计算每部分的行数
      final linesPerPart = (lines.length / 5).ceil();
      
      for (int i = 0; i < 5; i++) {
        final startIndex = i * linesPerPart;
        final endIndex = math.min((i + 1) * linesPerPart, lines.length);
        if (startIndex < lines.length) {
          parts.add(lines.sublist(startIndex, endIndex).join('\n'));
        } else {
          parts.add('');
        }
      }
    }
    
    return parts;
  }

  // 获取部分标题
  String _getPartTitle(int partIndex) {
    switch (partIndex) {
      case 0: return "开篇与背景铺垫";
      case 1: return "冲突展开";
      case 2: return "情节发展与转折";
      case 3: return "高潮与危机";
      case 4: return "结局与收尾";
      default: return "部分${partIndex + 1}";
    }
  }

  // 生成简短摘要
  String _generateBriefSummary(String content) {
    if (content.length <= 300) {
      return content;
    }
    
    // 提取最后300个字作为摘要基础
    final lastPortion = content.substring(content.length - 300);
    
    // 找到完整段落的开始
    final paragraphStart = lastPortion.indexOf('\n\n');
    if (paragraphStart > 0) {
      return lastPortion.substring(paragraphStart + 2);
    }
    
    // 如果找不到段落标记，直接返回最后部分
    return lastPortion;
  }
  
  // 增强内容以达到目标字数
  Future<String> _enhanceContentToMeetWordCount(
    String content, 
    int targetWordCount,
    String title,
    String style
  ) async {
    // 计算需要增加的字数
    final currentWordCount = content.length;
    final neededWords = targetWordCount - currentWordCount;
    
    // 如果差距不大，直接进行简单增强
    if (neededWords < targetWordCount * 0.2) {
      final enhancePrompt = '''
请对以下短篇小说进行细节丰富，增加描写，使总字数从当前的${currentWordCount}字增加到约${targetWordCount}字：

小说标题：$title
写作风格：$style

原小说内容：
$content

请通过以下方式增强内容：
1. 增加环境和场景的描写
2. 丰富人物动作和心理活动
3. 适当增加有意义的对话
4. 加入更多感官细节
5. 保持原有情节不变，只做扩充不做改变

请返回完整的增强后的小说内容。
''';

      return await _aiService.generateShortNovelContent(enhancePrompt);
    } 
    // 如果差距较大，需要更结构化的增强
    else {
      // 将内容分成5个部分
      final contentParts = _divideContentIntoParts(content, 5);
      String enhancedContent = '';
      
      // 逐部分增强
      for (int i = 0; i < contentParts.length; i++) {
        // 计算这部分需要增加的字数
        final partEnhanceTarget = (neededWords / contentParts.length).round();
        final targetPartLength = contentParts[i].length + partEnhanceTarget;
        
        final partEnhancePrompt = '''
请对短篇小说的第${i+1}部分进行细节丰富和内容扩展，使这部分从当前的${contentParts[i].length}字增加到约${targetPartLength}字：

小说标题：$title
写作风格：$style

当前第${i+1}部分内容：
${contentParts[i]}

请通过以下方式对这部分进行增强：
1. 增加环境和场景的描写
2. 丰富人物动作和心理活动
3. 适当增加有意义的对话
4. 加入更多感官细节
5. 增加转场和过渡段落
6. 保持原有情节不变，只做扩充

请返回完整的增强后的这部分内容。
''';

        final enhancedPart = await _aiService.generateShortNovelContent(partEnhancePrompt);
        
        if (i > 0) {
          enhancedContent += "\n\n" + enhancedPart;
        } else {
          enhancedContent = enhancedPart;
        }
        
        _updateRealtimeOutput("\n第${i+1}部分内容已增强，当前总字数：${enhancedContent.length}字\n");
      }
      
      return enhancedContent;
    }
  }
  
  // 将内容均匀分成指定数量的部分
  List<String> _divideContentIntoParts(String content, int numParts) {
    final paragraphs = content.split('\n\n');
    final List<String> parts = [];
    
    // 如果段落太少，无法有效分割
    if (paragraphs.length < numParts * 2) {
      // 尝试按字符均分
      final charsPerPart = (content.length / numParts).ceil();
      
      for (int i = 0; i < numParts; i++) {
        final startIndex = i * charsPerPart;
        if (startIndex < content.length) {
          final endIndex = math.min((i + 1) * charsPerPart, content.length);
          
          // 尝试在句子边界分割
          int adjustedEnd = endIndex;
          if (endIndex < content.length) {
            final nextPeriod = content.indexOf('。', endIndex);
            final nextQuestion = content.indexOf('？', endIndex);
            final nextExclamation = content.indexOf('！', endIndex);
            
            // 找到最近的句子结束符
            if (nextPeriod > 0 && (nextQuestion < 0 || nextPeriod < nextQuestion) 
                && (nextExclamation < 0 || nextPeriod < nextExclamation)) {
              adjustedEnd = nextPeriod + 1;
            } else if (nextQuestion > 0 && (nextExclamation < 0 || nextQuestion < nextExclamation)) {
              adjustedEnd = nextQuestion + 1;
            } else if (nextExclamation > 0) {
              adjustedEnd = nextExclamation + 1;
            }
          }
          
          parts.add(content.substring(startIndex, adjustedEnd));
        } else {
          parts.add('');
        }
      }
      
      return parts;
    }
    
    // 计算每部分的段落数
    final paragraphsPerPart = (paragraphs.length / numParts).ceil();
    
    for (int i = 0; i < numParts; i++) {
      final startIndex = i * paragraphsPerPart;
      if (startIndex < paragraphs.length) {
        final endIndex = math.min((i + 1) * paragraphsPerPart, paragraphs.length);
        parts.add(paragraphs.sublist(startIndex, endIndex).join('\n\n'));
      } else {
        parts.add('');
      }
    }
    
    return parts;
  }
  
  // 备选方法：在无法解析五段式大纲时直接生成完整内容
  Future<String> _generateFullStoryDirectly({
    required String title,
    required List<String> genres,
    required String background,
    required String otherRequirements,
    required String style,
    required String targetReader,
    required String outline,
    required int targetWordCount,
    required String characterPrompt,
  }) async {
    _updateRealtimeOutput("使用直接生成方式创作完整小说...\n");
    
    final initialPrompt = '''
你是一位优秀的短篇小说创作者。请根据以下大纲和要求，创作一篇完整的短篇小说：

小说标题：$title
小说类型：${genres.join('，')}
目标读者：$targetReader
写作风格：$style
${background.isNotEmpty ? '背景设定：$background\n' : ''}
${otherRequirements.isNotEmpty ? '其他要求：$otherRequirements\n' : ''}
$characterPrompt

大纲：
$outline

重要要求：
1. 请创作一篇结构完整的短篇小说，必须包含五个部分：开篇与背景铺垫、冲突展开、情节发展与转折、高潮与危机、结局与收尾
2. 小说总字数必须达到$targetWordCount字，每个部分要占适当比例
3. 请严格按照提供的大纲进行创作，确保所有情节点都有展开
4. 文风要符合"$style"的风格要求
5. 确保故事连贯、情节丰富、人物鲜活
6. 不要过早结束故事，确保内容丰满达到要求字数
7. 保证故事的连贯性，避免前后文脱节

请现在开始创作完整的短篇小说内容：
''';

    String content = await _aiService.generateShortNovelContent(initialPrompt);
    
    // 检查字数是否达到要求
    if (content.length < targetWordCount * 0.9) {
      _updateRealtimeOutput("\n当前字数不足(${content.length}/$targetWordCount)，需要增加内容...\n");
      
      // 增强内容以达到目标字数
      content = await _enhanceContentToMeetWordCount(
        content, 
        targetWordCount,
        title,
        style
      );
    }
    
    return content;
  }

  // 辅助方法：检测故事是否已有结局
  bool _detectStoryEnding(String content) {
    // 检查是否已经完整生成了五个部分
    bool hasFiveParts = true;
    
    // 检查五段式特征标记
    final partTitles = [
      "开篇与背景铺垫", "冲突展开", "情节发展与转折", "高潮与危机", "结局与收尾"
    ];
    
    for (var title in partTitles) {
      if (!content.contains(title) && !content.contains(title.replaceAll("与", ""))) {
        hasFiveParts = false;
        break;
      }
    }
    
    if (hasFiveParts) {
      return true; // 如果找到了所有五个部分的标记，认为故事完整
    }
    
    // 分析故事内容，检测是否已经有结局的迹象
    // 这里使用简单的启发式方法，检查最后10%的内容是否包含表示结局的关键词
    final lastPortion = content.length > 300 ? 
        content.substring(content.length - content.length ~/ 10) : content;
    
    final endingKeywords = [
      '结束', '完成', '终于', '最后', '从此', '永远', '这一天', 
      '余生', '未来', '新的开始', '告别', '道别', '终章', '结局',
      '最终', '一切都', '回到了', '结婚', '离开', '幸福地', '快乐地',
      '就这样', '后来', '多年后', '岁月', '随着时间', '走到了尽头'
    ];
    
    // 检查是否包含表示结局的段落标志
    if (lastPortion.contains('全剧终') || 
        lastPortion.contains('全文完') || 
        lastPortion.contains('—— 完 ——') ||
        lastPortion.contains('——完——') ||
        lastPortion.contains('（完）') ||
        lastPortion.contains('(完)') ||
        lastPortion.contains('END')) {
      return true;
    }
    
    // 检查是否包含结局关键词
    int keywordCount = 0;
    for (final keyword in endingKeywords) {
      if (lastPortion.contains(keyword)) {
        keywordCount++;
      }
      
      // 如果包含3个以上的结局关键词，认为故事已有结局
      if (keywordCount >= 3) {
        return true;
      }
    }
    
    // 检查内容长度，如果已经接近或超过目标字数，也认为故事基本完整
    // 这个检查在五段式结构下作为辅助判断
    if (content.length >= 13000) { // 通常目标是15000字，达到13000字已经接近完成
      return true;
    }
    
    return false;
  }
  
  // 辅助方法：将故事划分为开头、中间和结尾三部分
  Map<String, String> _divideStoryIntoParts(String content) {
    // 尝试定位五段式结构的分界点
    final partTitles = [
      "开篇与背景铺垫", "冲突展开", "情节发展与转折", "高潮与危机", "结局与收尾"
    ];
    
    final Map<String, int> partPositions = {};
    
    // 尝试找到各部分的位置
    for (final title in partTitles) {
      final titlePos = content.indexOf(title);
      if (titlePos > 0) {
        partPositions[title] = titlePos;
      } else {
        // 尝试不带"与"的变体
        final altTitle = title.replaceAll("与", "");
        final altPos = content.indexOf(altTitle);
        if (altPos > 0) {
          partPositions[title] = altPos;
        }
      }
    }
    
    // 如果找到了至少三个部分位置，按五段式划分
    if (partPositions.length >= 3) {
      final sortedPositions = partPositions.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      // 按部分名称分类存储
      final Map<String, String> result = {};
      
      // 处理开头部分
      final beginningTitle = sortedPositions.first.key;
      final beginningStart = sortedPositions.first.value;
      int beginningEnd = content.length;
      
      if (sortedPositions.length > 1) {
        beginningEnd = sortedPositions[1].value;
      }
      
      result['beginning'] = content.substring(0, beginningEnd);
      
      // 处理中间部分
      if (sortedPositions.length >= 3) {
        // 如果有3个以上部分，中间部分是第2到倒数第2
        final middleStart = sortedPositions[1].value;
        final middleEnd = sortedPositions[sortedPositions.length - 2].value;
        result['middle'] = content.substring(middleStart, middleEnd);
      } else if (sortedPositions.length == 2) {
        // 如果只有2个部分，第2部分当作中间
        result['middle'] = content.substring(sortedPositions[1].value);
      } else {
        result['middle'] = '';
      }
      
      // 处理结尾部分
      if (sortedPositions.length >= 2) {
        final endingTitle = sortedPositions.last.key;
        final endingStart = sortedPositions.last.value;
        result['ending'] = content.substring(endingStart);
      } else {
        result['ending'] = '';
      }
      
      return result;
    }
    
    // 如果无法按五段式划分，回退到按比例划分
    final paragraphs = content.split('\n\n');
    
    // 如果段落太少，无法有效划分
    if (paragraphs.length < 6) {
      final middleIndex = paragraphs.length ~/ 2;
      return {
        'beginning': paragraphs.take(1).join('\n\n') + '\n\n',
        'middle': paragraphs.sublist(1, paragraphs.length - 1).join('\n\n') + '\n\n',
        'ending': paragraphs.last
      };
    }
    
    // 将故事分为前20%、中间60%和后20%
    final beginningCount = (paragraphs.length * 0.2).ceil();
    final endingCount = (paragraphs.length * 0.2).ceil();
    final middleCount = paragraphs.length - beginningCount - endingCount;
    
    return {
      'beginning': paragraphs.take(beginningCount).join('\n\n') + '\n\n',
      'middle': paragraphs.sublist(beginningCount, beginningCount + middleCount).join('\n\n') + '\n\n',
      'ending': paragraphs.sublist(paragraphs.length - endingCount).join('\n\n')
    };
  }

  // 解析大纲,提取每章节的具体要求
  Map<int, Map<String, dynamic>> _parseOutline(String outline) {
    final Map<int, Map<String, dynamic>> chapterPlans = {};
    int currentChapter = 0;
    Map<String, dynamic>? currentPlan;
    
    final lines = outline.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      // 检测章节标题
      if (line.contains('第') && line.contains('章')) {
        // 保存前一章节的计划
        if (currentChapter > 0 && currentPlan != null) {
          chapterPlans[currentChapter] = currentPlan;
        }
        
        // 开始新的章节
        currentChapter = int.tryParse(
          line.replaceAll('第', '').replaceAll('章', '').trim()
        ) ?? 0;
        
        // 提取章节标题
        String chapterTitle = line.trim();
        if (line.contains('：')) {
          chapterTitle = line.split('：')[1].trim();
        } else if (line.contains(':')) {
          chapterTitle = line.split(':')[1].trim();
        }
        
        currentPlan = {
          'title': chapterTitle,
          'content': '',  // 初始化内容字段
          'mainPlots': <String>[],
          'subPlots': <String>[],
          'characterDev': <String>[],
          'foreshadowing': <String>[],
        };
      } 
      // 解析章节内容
      else if (currentPlan != null) {
        final trimmedLine = line.trim();
        // 累积章节内容
        currentPlan['content'] = '${currentPlan['content']}\n$trimmedLine';
        
        if (trimmedLine.startsWith('主要情节：') || trimmedLine.startsWith('- 主要情节：')) {
          currentPlan['mainPlots'].add(trimmedLine.replaceAll('主要情节：', '').replaceAll('- ', '').trim());
        } else if (trimmedLine.startsWith('次要情节：') || trimmedLine.startsWith('- 次要情节：')) {
          currentPlan['subPlots'].add(trimmedLine.replaceAll('次要情节：', '').replaceAll('- ', '').trim());
        } else if (trimmedLine.startsWith('人物发展：') || trimmedLine.startsWith('- 人物发展：')) {
          currentPlan['characterDev'].add(trimmedLine.replaceAll('人物发展：', '').replaceAll('- ', '').trim());
        } else if (trimmedLine.startsWith('伏笔：') || trimmedLine.startsWith('- 伏笔：')) {
          currentPlan['foreshadowing'].add(trimmedLine.replaceAll('伏笔：', '').replaceAll('- ', '').trim());
        }
      }
    }
    
    // 添加最后一章
    if (currentChapter > 0 && currentPlan != null) {
      chapterPlans[currentChapter] = currentPlan;
    }
    
    return chapterPlans;
  }

  // 构建章节生成上下文
  String _buildChapterContext({
    required String outline,
    required List<Chapter> previousChapters,
    required int currentNumber,
    required int totalChapters,
  }) {
    final buffer = StringBuffer();
    final currentPlan = _parseOutline(outline);
    
    buffer.writeln('【小说大纲】');
    buffer.writeln(outline);
    buffer.writeln();
    
    buffer.writeln('【当前章节】');
    buffer.writeln('章节编号: $currentNumber / $totalChapters');
    buffer.writeln('章节标题: ${currentPlan[currentNumber]?['title'] ?? "未知标题"}');
    buffer.writeln('章节内容: ${currentPlan[currentNumber]?['content'] ?? "未知内容"}');
    buffer.writeln();
    
    if (previousChapters.isNotEmpty) {
      // 添加所有前文章节的完整内容，而不只是摘要
      buffer.writeln('【前序章节详细内容】');
      
      // 计算包含多少前序章节的完整内容
      // 默认情况下包含最近3章的完整内容和其余章节的摘要
      int fullContentChapters = 3;
      
      // 如果章节数量不多，可以包含所有前序章节
      if (previousChapters.length <= fullContentChapters) {
        for (var i = 0; i < previousChapters.length; i++) {
          buffer.writeln('第${previousChapters[i].number}章: ${previousChapters[i].title}');
          buffer.writeln(previousChapters[i].content);
          buffer.writeln();
        }
      } else {
        // 先添加除了最近几章外的所有章节摘要
        buffer.writeln('【前序章节摘要】');
        for (var i = 0; i < previousChapters.length - fullContentChapters; i++) {
          buffer.writeln('第${previousChapters[i].number}章: ${previousChapters[i].title}');
          buffer.writeln(_generateChapterSummary(previousChapters[i].content));
          buffer.writeln();
        }
        
        // 然后添加最近几章的完整内容
        buffer.writeln('【最近章节完整内容】');
        for (var i = previousChapters.length - fullContentChapters; i < previousChapters.length; i++) {
          buffer.writeln('第${previousChapters[i].number}章: ${previousChapters[i].title}');
          buffer.writeln(previousChapters[i].content);
          buffer.writeln();
        }
      }
    }
    
    return buffer.toString();
  }

  // 清理生成的内容，移除大纲标记
  String _cleanGeneratedContent(String content) {
    // 需要过滤的标记列表
    final markersToRemove = [
      '主要情节：',
      '次要情节：',
      '人物发展：',
      '伏笔：',
      '伏笔与悬念：',
      '【本章规划】',
      '【前文概要】',
      '【后续章节规划】',
      '标题：',
    ];
    
    // 分行处理
    final lines = content.split('\n');
    final cleanedLines = <String>[];
    var lastLineWasEmpty = true; // 跟踪上一行是否为空
    
    for (var line in lines) {
      final trimmedLine = line.trim();
      
      // 跳过需要过滤的标记行
      bool shouldSkip = false;
      for (final marker in markersToRemove) {
        if (trimmedLine.startsWith(marker) || 
            trimmedLine.startsWith('- $marker') ||
            trimmedLine == '-') {
          shouldSkip = true;
          break;
        }
      }
      
      // 跳过纯数字编号的行
      if (RegExp(r'^\d+\.$').hasMatch(trimmedLine)) {
        shouldSkip = true;
      }
      
      if (shouldSkip) continue;
      
      // 处理空行
      if (trimmedLine.isEmpty) {
        if (!lastLineWasEmpty) {
          cleanedLines.add('');
          lastLineWasEmpty = true;
        }
        continue;
      }
      
      // 添加非空行
      cleanedLines.add(trimmedLine);
      lastLineWasEmpty = false;
    }
    
    // 确保文本不以空行开始或结束
    while (cleanedLines.isNotEmpty && cleanedLines.first.isEmpty) {
      cleanedLines.removeAt(0);
    }
    while (cleanedLines.isNotEmpty && cleanedLines.last.isEmpty) {
      cleanedLines.removeLast();
    }
    
    // 合并处理后的内容，确保段落之间有一个空行
    return cleanedLines.join('\n');
  }

  // 生成章节内容的方法
  Future<String> _generateChapterContent({
    required String title,
    required int number,
    required String outline,
    required List<Chapter> previousChapters,
    required int totalChapters,
    required String genre,
    required String theme,
    String? style,
    required String targetReaders,
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      // 解析章节规划
      final chapterPlans = _parseOutline(outline);
      
      // 构建章节上下文
      final context = _buildChapterContext(
        outline: outline,
        previousChapters: previousChapters,
        currentNumber: number,
        totalChapters: totalChapters,
      );
      
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final novelController = Get.find<NovelController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(novelController.targetReader.value);
      
      // 没有指定风格时使用默认风格策略
      final currentStyle = style ?? _determineStyle(number, totalChapters, null);
      
      // 构建完整提示词
      final prompt = '''
${context}

${masterPrompt.isNotEmpty ? "全局指导：\n" + masterPrompt + "\n\n" : ""}
${targetReaderPrompt.isNotEmpty ? "目标读者：\n" + targetReaderPrompt + "\n\n" : ""}

写作要求：
1. 创作风格：$currentStyle
2. 不要以"第X章"或章节标题开头
3. 详细展开本章情节，符合大纲中描述的内容和主题
4. 与前文保持连贯，延续已建立的情节线和角色发展
5. 章节长度控制在3000-5000字之间
6. 不要在正文中出现"未完待续"等结束语
''';

      // 使用AI服务生成内容
      onProgress?.call('正在生成第$number章...');
      
      // 如果有onContent回调，使用它来显示生成进度
      if (onContent != null) {
        onContent('\n开始生成第$number章内容...\n');
      }
      
      // 使用对话ID生成章节内容
      final generatedContent = await _aiService.generateChapterContent(prompt, novelTitle: title, chapterNumber: number);
      
      // 清理内容格式
      String cleanedContent = _cleanGeneratedContent(generatedContent);
      
      // 检查章节连贯性并修复问题（即使使用对话ID，仍然进行检查，确保最高质量）
      if (previousChapters.isNotEmpty) {
        onProgress?.call('正在检查内容连贯性...');
        cleanedContent = await _ensureChapterCoherence(
          generatedContent: cleanedContent, 
          previousChapters: previousChapters,
          outline: outline,
          chapterNumber: number,
          onProgress: onProgress,
        );
      }
      
      onProgress?.call('第$number章生成完成');
      
      return cleanedContent;
    } catch (e) {
      print('生成章节内容失败: $e');
      throw Exception('生成章节内容失败: $e');
    }
  }

  // 添加清理生成失败的缓存的方法
  void clearFailedGenerationCache() {
    // 清空段落记录，避免重复检测时包含失败的内容
    _generatedParagraphs.clear();
  }

  // 添加_extractChapterTitle方法
  String _extractChapterTitle(String content, int number) {
    // 尝试匹配"第X章：标题"或"第X章 标题"格式
    final RegExp titleRegex = RegExp(r'第' + number.toString() + r'章[：\s]+(.*?)[\n\r]');
    final match = titleRegex.firstMatch(content);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? '第$number章';
    }
    return '第$number章';
  }

  /// 将大纲分成五个部分
  List<String> _divideOutlineIntoFiveParts(String outline) {
    // 尝试按照明确的分隔符分割
    final parts = RegExp(r'第(\d+)部分[：:](.*?)(?=第\d+部分[：:]|$)', dotAll: true)
        .allMatches(outline)
        .map((m) => m.group(0)!)
        .toList();
    
    if (parts.length == 5) {
      return parts;
    }
    
    // 如果没有明确的分隔符，尝试按照段落分割
    final paragraphs = outline.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.length >= 5) {
      // 将段落合并为5个部分
      final partSize = paragraphs.length ~/ 5;
      final result = <String>[];
      
      for (int i = 0; i < 5; i++) {
        final start = i * partSize;
        final end = i == 4 ? paragraphs.length : (i + 1) * partSize;
        result.add(paragraphs.sublist(start, end).join('\n\n'));
      }
      
      return result;
    }
    
    // 应该不会到这里，但为了安全起见
    return List.generate(5, (index) => '第${index + 1}部分');
  }

  // 将长文本摘要为指定长度
  String _summarizeText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    
    // 简单截取前半部分和后半部分，中间用...替代
    final halfLength = (maxLength / 2).floor();
    final firstPart = text.substring(0, halfLength);
    final lastPart = text.substring(text.length - halfLength);
    
    return '$firstPart...$lastPart';
  }
  
  // 清理章节内容，删除可能的前缀
  String _cleanChapterContent(String content) {
    // 删除可能包含的章节标题前缀
    final titlePrefixPattern = RegExp(r'^第\d+章[：:][^\n]*\n+');
    return content.replaceFirst(titlePrefixPattern, '').trim();
  }

  Future<String> _generateChapter({
    required String title,
    required String genre,
    required String theme,
    required String outline,
    required int chapterNumber,
    required int totalChapters,
    required List<Chapter> previousChapters,
    void Function(String)? onContent,
    Map<String, CharacterCard>? characterCards,
    List<CharacterType>? characterTypes,
  }) async {
    try {
      // 清理之前可能失败的缓存
      clearFailedGenerationCache();
      
      // 检查是否有缓存
      final chapterKey = 'chapter_${title}_$chapterNumber';
      final cachedContent = await _checkCache(chapterKey);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        print('使用缓存的章节内容: $chapterKey');
        if (onContent != null) {
          onContent('使用缓存内容...');
          onContent(cachedContent);
        }
        return cachedContent;
      }
      
      // 从大纲中提取当前章节的信息
      String chapterTitle = '第$chapterNumber章';
      String chapterOutline = '';
      
      // 尝试从大纲中提取章节信息
      // 首先检查是否是导入的结构化大纲
      if (outline.contains('"chapter_number":') || outline.contains('"chapterNumber":')) {
        try {
          // 尝试解析JSON格式大纲
          Map<String, dynamic> outlineJson;
          try {
            outlineJson = jsonDecode(outline);
          } catch (e) {
            // 如果直接解析失败，尝试提取JSON部分
            final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(outline);
            if (jsonMatch != null) {
              outlineJson = jsonDecode(jsonMatch.group(0)!);
            } else {
              throw Exception('无法解析大纲JSON');
            }
          }
          
          // 查找当前章节
          if (outlineJson.containsKey('chapters')) {
            final chapters = outlineJson['chapters'] as List;
            for (final chapter in chapters) {
              final chapterMap = chapter as Map<String, dynamic>;
              final chapterNum = chapterMap.containsKey('chapter_number') 
                  ? chapterMap['chapter_number'] 
                  : chapterMap['chapterNumber'];
                  
              if (chapterNum == chapterNumber) {
                final chapterTitleKey = chapterMap.containsKey('chapter_title') 
                    ? 'chapter_title' 
                    : 'chapterTitle';
                final chapterOutlineKey = chapterMap.containsKey('content_outline') 
                    ? 'content_outline' 
                    : 'contentOutline';
                    
                chapterTitle = '第$chapterNumber章：${chapterMap[chapterTitleKey]}';
                chapterOutline = chapterMap[chapterOutlineKey];
                print('从JSON大纲中提取到章节信息: $chapterTitle');
                break;
              }
            }
          }
        } catch (e) {
          print('解析JSON大纲失败: $e，将使用正则表达式提取');
        }
      }
      
      // 如果上面的方法没有找到章节信息，使用正则表达式提取
      if (chapterOutline.isEmpty) {
        final chapterPattern = RegExp(r'第' + chapterNumber.toString() + r'章[：:](.*?)\n(.*?)(?=第\d+章|$)', dotAll: true);
        final match = chapterPattern.firstMatch(outline);
        
        if (match != null) {
          chapterTitle = '第$chapterNumber章：${match.group(1)?.trim() ?? ''}';
          chapterOutline = match.group(2)?.trim() ?? '';
          print('使用正则表达式从大纲中提取到章节信息');
        } else {
          // 如果没有找到匹配的章节信息，尝试查找NovelOutline对象
          try {
            final novelController = Get.find<NovelController>();
            if (novelController.currentOutline.value != null) {
              final outlineChapter = novelController.currentOutline.value!.chapters
                  .firstWhere((ch) => ch.chapterNumber == chapterNumber, 
                      orElse: () => ChapterOutline(
                        chapterNumber: chapterNumber, 
                        chapterTitle: '第$chapterNumber章', 
                        contentOutline: ''));
                        
              chapterTitle = '第$chapterNumber章：${outlineChapter.chapterTitle}';
              chapterOutline = outlineChapter.contentOutline;
              print('从NovelController中获取到章节信息');
            }
          } catch (e) {
            print('从NovelController获取章节信息失败: $e');
          }
          
          // 如果仍然没有找到章节信息，使用通用描述
          if (chapterOutline.isEmpty) {
            chapterOutline = '这是第$chapterNumber章的内容';
            print('未找到章节大纲，使用默认描述');
          }
        }
      }
      
      print('章节大纲: $chapterOutline');
      
      // 获取前一章的内容作为上下文参考
      String previousContent = '';
      if (previousChapters.isNotEmpty) {
        final lastChapter = previousChapters.last;
        // 内联实现_summarizeText方法
        String summarizedContent = lastChapter.content;
        if (summarizedContent.length > 500) {
          final halfLength = (500 / 2).floor();
          final firstPart = summarizedContent.substring(0, halfLength);
          final lastPart = summarizedContent.substring(summarizedContent.length - halfLength);
          summarizedContent = '$firstPart...$lastPart';
        }
        previousContent = '前一章内容概要：${lastChapter.title}\n${summarizedContent}';
      }
      
      // 构建包含角色信息的提示词
      String characterPrompt = '';
      if (characterCards != null && characterCards.isNotEmpty && characterTypes != null) {
        characterPrompt = '小说角色设定：\n';
        for (final type in characterTypes) {
          final card = characterCards[type.id];
          if (card != null) {
            characterPrompt += '${type.name}：${card.name}\n';
            
            if (card.gender != null && card.gender!.isNotEmpty) {
              characterPrompt += '性别：${card.gender}\n';
            }
            
            if (card.age != null && card.age!.isNotEmpty) {
              characterPrompt += '年龄：${card.age}\n';
            }
            
            if (card.personalityTraits != null && card.personalityTraits!.isNotEmpty) {
              characterPrompt += '性格：${card.personalityTraits}\n';
            }
            
            if (card.background != null && card.background!.isNotEmpty) {
              characterPrompt += '背景：${card.background}\n';
            }
            
            // 添加更详细的角色信息
            if (card.bodyDescription != null && card.bodyDescription!.isNotEmpty) {
              characterPrompt += '身体特征：${card.bodyDescription}\n';
            }
            
            if (card.faceFeatures != null && card.faceFeatures!.isNotEmpty) {
              characterPrompt += '面部特征：${card.faceFeatures}\n';
            }
            
            if (card.motivation != null && card.motivation!.isNotEmpty) {
              characterPrompt += '动机：${card.motivation}\n';
            }
            
            if (card.shortTermGoals != null && card.shortTermGoals!.isNotEmpty) {
              characterPrompt += '短期目标：${card.shortTermGoals}\n';
            }
            
            if (card.longTermGoals != null && card.longTermGoals!.isNotEmpty) {
              characterPrompt += '长期目标：${card.longTermGoals}\n';
            }
            
            characterPrompt += '\n';
          }
        }
      }
      
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final novelController = Get.find<NovelController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final chapterPrompt = promptPackageController.getCurrentPromptContent('chapter');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(novelController.targetReader.value);
      
      // 根据目标读者选择不同的提示词
      String chapterGenPrompt;
      
      if (novelController.targetReader.value == '女性向') {
        // 使用女性向提示词
        chapterGenPrompt = FemalePrompts.getChapterPrompt(
          title, 
          genre, 
          chapterNumber, 
          totalChapters, 
          chapterTitle, 
          chapterOutline
        );
      } else {
        // 默认使用男性向提示词
        chapterGenPrompt = MalePrompts.getChapterPrompt(
          title, 
          genre, 
          chapterNumber, 
          totalChapters, 
          chapterTitle, 
          chapterOutline
        );
      }
      
      // 构建完整提示词
      final prompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${chapterPrompt.isNotEmpty ? chapterPrompt + '\n\n' : ''}
${targetReaderPrompt.isNotEmpty ? targetReaderPrompt + '\n\n' : ''}
${characterPrompt.isNotEmpty ? characterPrompt + '\n\n' : ''}
${previousContent.isNotEmpty ? previousContent + '\n\n' : ''}

${chapterGenPrompt}
''';

      print('正在生成第$chapterNumber章...');
      if (onContent != null) {
        onContent('正在生成...');
      }
      
      // 生成章节内容
      String content = '';
      // 使用专门的章节生成方法，对接章节模型
      await for (final chunk in _aiService.generateChapterTextStream(
        systemPrompt: prompt,
        userPrompt: '请开始创作第$chapterNumber章的内容',
        maxTokens: _getMaxTokensForChapter(chapterNumber),
        temperature: 0.7,
      )) {
        content += chunk;
        if (onContent != null) {
          onContent(chunk);
        }
      }
      
      // 净化内容，删除可能的前缀
      final titlePrefixPattern = RegExp(r'^第\d+章[：:][^\n]*\n+');
      content = content.replaceFirst(titlePrefixPattern, '').trim();
      
      // 检查内容质量
      if (content.length < 500) {
        throw Exception('生成的内容过短，质量不合格');
      }
      
      // 缓存章节内容
      await _cacheService.cacheContent(chapterKey, content);
      
      return content;
    } catch (e) {
      print('生成章节失败: $e');
      throw Exception('生成章节内容失败: $e');
    }
  }

  // 添加暂停生成的方法
  void pauseGeneration() {
    if (!_isPaused.value) {
      _isPaused.value = true;
      if (_pauseCompleter == null || _pauseCompleter!.isCompleted) {
        _pauseCompleter = Completer<void>();
      }
    }
  }

  // 添加继续生成的方法
  void resumeGeneration() {
    if (_isPaused.value) {
      _isPaused.value = false;
      if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
        _pauseCompleter!.complete();
      }
      _pauseCompleter = null;
    }
  }

  // 检查是否需要暂停
  Future<void> _checkPause() async {
    if (_isPaused.value) {
      if (_pauseCompleter == null || _pauseCompleter!.isCompleted) {
        _pauseCompleter = Completer<void>();
      }
      await _pauseCompleter!.future;
    }
  }

  // 添加清除生成进度的方法
  Future<void> clearGenerationProgress() async {
    final box = await Hive.openBox('generation_progress');
    await box.delete('last_generation');
  }

  // 添加保存生成进度的方法
  Future<void> _saveGenerationProgress({
    required String title,
    required String genre,
    required String theme,
    required String targetReaders,
    required int totalChapters,
    required String outline,
    required List<Chapter> chapters,
  }) async {
    final box = await Hive.openBox('generation_progress');
    await box.put('last_generation', {
      'title': title,
      'genre': genre,
      'theme': theme,
      'target_readers': targetReaders,
      'total_chapters': totalChapters,
      'outline': outline,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 处理段落生成
  Future<String> _handleParagraphGeneration(String paragraph, {
    required String title,
    required int chapterNumber,
    required String outline,
    required Map<String, dynamic> context,
  }) async {
    // 1. 检查重复度
    final checkResult = _checkParagraphDuplicate(paragraph);
    
    // 2. 根据重复度采取不同策略
    if (checkResult.isDuplicate) {
      if (checkResult.similarity >= HIGH_SIMILARITY_THRESHOLD) {
        // 高重复度：完全重新生成
        final newContent = await _regenerateParagraph(
          title: title,
          chapterNumber: chapterNumber,
          outline: outline,
          context: context,
          avoidKeywords: checkResult.duplicateKeywords,
        );
        
        // 添加新生成的内容到记录中
        _addGeneratedParagraph(newContent);
        return newContent;
      } else if (checkResult.similarity >= MEDIUM_SIMILARITY_THRESHOLD) {
        // 中等重复度：修改现有内容
        final modifiedContent = await _modifyParagraph(
          paragraph,
          checkResult.duplicateKeywords,
          context: context,
        );
        
        // 添加修改后的内容到记录中
        _addGeneratedParagraph(modifiedContent);
        return modifiedContent;
      }
    }

    // 重复度低或无重复：保存并返回原段落
    _addGeneratedParagraph(paragraph);
    return paragraph;
  }

  Future<String> _regenerateParagraph({
    required String title,
    required int chapterNumber,
    required String outline,
    required Map<String, dynamic> context,
    required List<String> avoidKeywords,
  }) async {
    final regeneratePrompt = '''
请重新生成一段内容，要求：
1. 避免使用以下关键词或相似表达：${avoidKeywords.join(', ')}
2. 保持与上下文的连贯性
3. 使用不同的表达方式和描写角度
4. 确保内容符合当前章节主题

当前上下文：
${context['currentContext']}

章节主题：
${context['chapterTheme']}
''';

    String newContent = await _generateWithAI(
      regeneratePrompt,
      temperature: 0.9,
      repetitionPenalty: 1.5,
    );

    return newContent;
  }

  Future<String> _modifyParagraph(
    String paragraph,
    List<String> duplicateKeywords,
    {required Map<String, dynamic> context}
  ) async {
    final modifyPrompt = '''
请修改以下段落，要求：
1. 保持主要情节不变
2. 使用不同的表达方式
3. 避免使用这些词语：${duplicateKeywords.join(', ')}
4. 改变描写视角或细节

原段落：
$paragraph

修改要求：
1. 更换重复的描写方式
2. 增加新的细节
3. 调整句子结构
''';

    String modifiedContent = await _generateWithAI(
      modifyPrompt,
      temperature: 0.8,
      repetitionPenalty: 1.4,
    );

    return modifiedContent;
  }

  // 修改 _generateWithAI 方法以支持更多参数
  Future<String> _generateWithAI(
    String prompt, {
    double temperature = 0.7,
    double repetitionPenalty = 1.3,
    String? novelTitle,
    bool useOutlineModel = false,
  }) async {
    try {
      String response = '';
      
      // 根据需要选择使用大纲模型或章节模型
      if (useOutlineModel) {
        await for (final chunk in _aiService.generateOutlineTextStream(
          systemPrompt: MasterPrompts.basicPrinciples,
          userPrompt: prompt,
          temperature: temperature,
          repetitionPenalty: repetitionPenalty,
          maxTokens: _apiConfig.getOutlineModel().maxTokens,
          topP: _apiConfig.getOutlineModel().topP,
          // 如果提供了小说标题，AI服务内部会创建或获取相应的对话ID
          novelTitle: novelTitle,
        )) {
          response += chunk;
        }
      } else {
        // 使用章节模型
        await for (final chunk in _aiService.generateChapterTextStream(
          systemPrompt: MasterPrompts.basicPrinciples,
          userPrompt: prompt,
          temperature: temperature,
          repetitionPenalty: repetitionPenalty,
          maxTokens: _apiConfig.getChapterModel().maxTokens,
          topP: _apiConfig.getChapterModel().topP,
          // 如果提供了小说标题，AI服务内部会创建或获取相应的对话ID
          novelTitle: novelTitle,
        )) {
          response += chunk;
        }
      }
      
      return response;
    } catch (e) {
      print('生成失败: $e');
      rethrow;
    }
  }
  
  DuplicateCheckResult _checkParagraphDuplicate(String paragraph) {
    if (_generatedParagraphs.isEmpty) {
      return DuplicateCheckResult(isDuplicate: false, similarity: 0.0);
    }

    double maxSimilarity = 0.0;
    String mostSimilarParagraph = '';
    List<String> duplicateKeywords = [];

    for (var existingParagraph in _generatedParagraphs) {
      final similarity = _calculateSimilarity(
        paragraph,
        existingParagraph.content
      );

      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
        mostSimilarParagraph = existingParagraph.content;
        duplicateKeywords = existingParagraph.keywords;
      }
    }

    return DuplicateCheckResult(
      isDuplicate: maxSimilarity >= MEDIUM_SIMILARITY_THRESHOLD,
      similarity: maxSimilarity,
      duplicateSource: mostSimilarParagraph,
      duplicateKeywords: duplicateKeywords,
    );
  }

  double _calculateSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;
    
    // 将文本转换为字符集合
    final set1 = text1.split('').toSet();
    final set2 = text2.split('').toSet();
    
    // 计算Jaccard相似度
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    
    return intersection / union;
  }

  // 检查生成的章节内容与前文的连贯性，必要时进行修复
  Future<String> _ensureChapterCoherence({
    required String generatedContent, 
    required List<Chapter> previousChapters,
    required String outline,
    required int chapterNumber,
    void Function(String)? onProgress,
  }) async {
    // 如果没有前文，或者是第一章，则无需检查连贯性
    if (previousChapters.isEmpty || chapterNumber <= 1) {
      return generatedContent;
    }
    
    onProgress?.call('正在检查章节连贯性...');
    
    try {
      // 构建连贯性检查提示词
      final buffer = StringBuffer();
      
      // 添加最近的前文摘要
      buffer.writeln('【前文摘要】');
      // 最多添加3章的摘要
      final int maxPrevChapters = previousChapters.length < 3 ? previousChapters.length : 3;
      for (var i = previousChapters.length - maxPrevChapters; i < previousChapters.length; i++) {
        buffer.writeln('第${previousChapters[i].number}章: ${previousChapters[i].title}');
        buffer.writeln(_generateChapterSummary(previousChapters[i].content));
        buffer.writeln();
      }
      
      // 添加当前章节大纲和内容
      final currentChapterOutline = _extractChapterOutline(outline, chapterNumber);
      buffer.writeln('【当前章节大纲】');
      buffer.writeln(currentChapterOutline);
      buffer.writeln();
      
      buffer.writeln('【当前章节内容】');
      buffer.writeln(generatedContent);
      
      // 构建检查连贯性的提示词
      final String coherenceCheckPrompt = '''
请分析以下内容，检查当前章节内容与前文的连贯性问题：

${buffer.toString()}

请检查以下几个方面的连贯性：
1. 人物一致性：人物的性格、能力、外表描述等是否与前文一致
2. 情节连贯性：当前章节的事件是否基于前文自然发展，是否存在逻辑跳跃
3. 设定一致性：世界观、规则、地点描述等是否与前文一致
4. 时间线一致性：事件发生的顺序和时间是否合理，与前文衔接
5. 人物关系一致性：角色之间的关系是否与前文描述一致

只回答"有连贯性问题"或"无连贯性问题"。
''';

      // 检查连贯性
      String coherenceCheckResult = '';
      try {
        coherenceCheckResult = await _aiService.generateText(
          systemPrompt: "你是一个专业的小说编辑，负责检查章节之间的连贯性问题。请准确判断当前章节内容是否与前文保持连贯，只回答'有连贯性问题'或'无连贯性问题'。",
          userPrompt: coherenceCheckPrompt,
          temperature: 0.2, // 低温度，提高确定性
          maxTokens: 50, // 简短回答即可
        );
      } catch (e) {
        print('检查章节连贯性失败: $e');
        return generatedContent; // 出错时返回原始内容
      }
      
      // 如果检测到连贯性问题，尝试修复
      if (coherenceCheckResult.toLowerCase().contains("有连贯性问题")) {
        onProgress?.call('检测到连贯性问题，正在修复...');
        print('检测到章节连贯性问题，尝试修复...');
        
        try {
          // 构建修复提示词
          final String fixPrompt = '''
请修复以下小说章节内容中存在的连贯性问题。确保修复后的内容与前文在人物、情节、设定等方面保持连贯。

${buffer.toString()}

连贯性问题主要包括：
1. 人物不一致：性格、能力、外表描述等与前文不符
2. 情节断层：当前章节的事件与前文衔接不自然，存在逻辑跳跃
3. 设定冲突：世界观、规则、地点描述等与前文冲突
4. 时间线混乱：事件发生的顺序和时间不合理，与前文脱节
5. 人物关系混乱：角色之间的关系与前文描述不一致

请提供修复后的完整章节内容，确保与前文自然衔接，情节流畅，人物和设定一致。
修复时应保留当前章节的主要情节和核心内容，只调整存在连贯性问题的部分。
''';

          // 尝试修复连贯性问题
          String fixedContent = await _aiService.generateText(
            systemPrompt: "你是一个专业的小说编辑，负责修复章节之间的连贯性问题。请对当前章节内容进行修改，确保它与前文在人物、情节、设定等方面保持连贯。",
            userPrompt: fixPrompt,
            temperature: 0.7, // 中等温度，允许一定创造性
            maxTokens: 4000, // 确保能生成完整章节
          );
          
          // 如果修复后的内容不为空且不太短，返回修复后的内容
          if (fixedContent.isNotEmpty && fixedContent.length >= generatedContent.length * 0.7) {
            onProgress?.call('连贯性问题修复完成');
            print('章节连贯性问题修复完成');
            return fixedContent;
          }
        } catch (e) {
          print('修复章节连贯性失败: $e');
        }
      } else {
        onProgress?.call('章节连贯性检查通过');
        print('章节连贯性检查通过');
      }
    } catch (e) {
      print('连贯性检查过程出错: $e');
    }
    
    // 如果没有问题或修复失败，返回原始内容
    return generatedContent;
  }

  // 从大纲中提取特定章节的内容
  String _extractChapterOutline(String outline, int chapterNumber) {
    // 尝试匹配第N章的整个内容块
    final RegExp chapterRegex = RegExp(r'第' + chapterNumber.toString() + r'章.*?(?=第' + (chapterNumber + 1).toString() + r'章|$)', dotAll: true);
    final match = chapterRegex.firstMatch(outline);
    if (match != null) {
      return match.group(0) ?? '';
    }
    
    // 如果未找到匹配，则尝试从解析的大纲中获取
    final chapterPlans = _parseOutline(outline);
    if (chapterPlans.containsKey(chapterNumber)) {
      return chapterPlans[chapterNumber]?['content'] ?? '';
    }
    
    return '无法提取第$chapterNumber章的大纲内容';
  }

  // 重新生成章节内容
  Future<String> regenerateChapter({
    required String title,
    required int number,
    required String outline,
    required List<Chapter> previousChapters,
    required int totalChapters,
    required String genre,
    required String theme,
    required String targetReaders,
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      // 清除当前小说的对话ID，以便重新开始对话
      _aiService.clearNovelConversation(title);
      
      // 构建章节上下文
      final context = _buildChapterContext(
        outline: outline,
        previousChapters: previousChapters,
        currentNumber: number,
        totalChapters: totalChapters,
      );
      
      // 获取章节的需求
      final chapterPlans = _parseOutline(outline);
      
      // 获取上次的标题
      final oldChapter = previousChapters.firstWhere((c) => c.number == number, orElse: () => Chapter(number: number, title: '第$number章', content: ''));
      
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final novelController = Get.find<NovelController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(novelController.targetReader.value);
      
      // 设置当前风格，尝试使用不同的风格
      final newStyle = _getRandomStyle();
      style = newStyle;
      
      // 构建提示词
      final systemPrompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${targetReaderPrompt.isNotEmpty ? targetReaderPrompt + '\n\n' : ''}
${ChapterGeneration.getSystemPrompt(style)}

【特别要求】
这次创作是对前一版本的重写改进，请注意：
1. 保持原有的主要情节和角色设定，但请使用不同的表达方式和场景描写
2. 避免与前一版本过于相似，争取有新鲜的表达和视角
3. 增加更多细节描写和角色心理活动
4. 提升情节的紧凑度和冲突的张力
''';
      
      final userPrompt = ChapterGeneration.getChapterPrompt(
        title: title,
        chapterNumber: number,
        totalChapters: totalChapters,
        outline: outline,
        previousChapters: previousChapters,
        genre: genre,
        theme: theme,
        style: style,
        targetReaders: targetReaders,
      );
      
      // 使用流式生成
      final buffer = StringBuffer();
      
      onProgress?.call('正在重新生成第$number章...');
      
      // 确保回调函数被调用
      if (onContent != null) {
        onContent('\n开始重新生成第$number章内容...\n');
      }
      
      // 创建特殊的重生成对话ID
      final regenerateConversationId = '_regenerate_${title.replaceAll(' ', '_')}_${number}_${DateTime.now().millisecondsSinceEpoch}';
      
      // 重新生成时使用新的对话ID，避免受到之前生成内容的限制
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: _getMaxTokensForChapter(number),
        temperature: 0.85,  // 增加温度以获得更多变化
        conversationId: regenerateConversationId, // 使用专门的重生成对话ID
      )) {
        // 检查是否暂停
        await _checkPause();
        
        // 更新内容
        final cleanedChunk = ChapterGeneration.formatChapter(chunk);
        buffer.write(cleanedChunk);
        
        // 调用回调函数
        if (onContent != null) {
          onContent(cleanedChunk);
        }
      }
      
      String newContent = _cleanGeneratedContent(buffer.toString());
      
      // 检查连贯性并修复
      if (previousChapters.isNotEmpty) {
        // 过滤掉当前章节
        final prevChapters = previousChapters.where((c) => c.number != number).toList();
        if (prevChapters.isNotEmpty) {
          newContent = await _ensureChapterCoherence(
            generatedContent: newContent,
            previousChapters: prevChapters,
            outline: outline,
            chapterNumber: number,
            onProgress: onProgress,
          );
        }
      }
      
      onProgress?.call('第$number章重新生成完成');
      
      return newContent;
    } catch (e) {
      print('重新生成章节失败: $e');
      throw Exception('重新生成章节失败: $e');
    }
  }

  String _getRandomStyle() {
    final styles = [
      '细腻写实',
      '跌宕起伏',
      '悬疑迷离',
      '热血激昂',
      '温情脉脉',
      '峰回路转',
      '诙谐幽默',
      '沉稳大气',
      '清新淡雅',
      '惊心动魄',
      '青春活力',
      '古典婉约',
      '烟火人间',
      '灵动轻盈',
      '浪漫唯美',
      '意境深远',
      '克制含蓄',
      '浓墨重彩',
      '铁血硬朗',
      '潇洒飘逸'
    ];
    
    // 随机选择一种风格
    final random = Random();
    return styles[random.nextInt(styles.length)];
  }
} 