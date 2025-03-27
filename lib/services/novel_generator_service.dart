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
import 'package:novel_app/services/langchain_novel_generator_service.dart';

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
  /*
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
  */

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
      // 获取LangChain服务（如果可用）
      LangchainNovelGeneratorService? langchainService;
      try {
        langchainService = Get.find<LangchainNovelGeneratorService>();
      } catch(e) {
        print('LangChain服务不可用: $e');
      }
      
      // 获取API配置控制器
      final apiConfig = Get.find<ApiConfigController>();
      
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
      final int batchSize = 5; // 减少每批处理的章节数，提高连贯性
      final StringBuffer fullOutlineBuffer = StringBuffer();
      
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
        conversationId: null, // 使用全局对话ID，不再创建专用ID
      )) {
        structureContent += chunk;
        if (onContent != null) {
          onContent(chunk);
        }
      }
      
      // 将结构和情节线保存下来，用于后续章节生成参考
      final String structureAndPlotContent = structureContent.trim();
      
      // 添加大纲的整体架构和主要情节线到缓冲区
      fullOutlineBuffer.writeln(structureContent.trim());
      fullOutlineBuffer.writeln("\n三、具体章节");
      
      // 保存已生成的章节大纲内容，用于后续章节生成参考
      StringBuffer generatedChaptersBuffer = StringBuffer();
      
      // 分批生成章节大纲
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

        // 使用标准大纲生成
        String batchContent = '';
        // 所有批次都使用标准流式生成，不再区分是第一批次还是后续批次
        try {
          // 获取上下文（如果存在）
          String contextPrompt = '';
          if (startChapter > 1 && generatedChaptersBuffer.isNotEmpty) {
            String previousContent = generatedChaptersBuffer.toString().trim();
            // 限制前一部分的长度，避免提示词过长
            if (previousContent.length > 3000) {
              previousContent = previousContent.substring(previousContent.length - 3000);
            }
            
            // 构建包含上下文的提示词
            contextPrompt = '''
请注意以下要求：
1. 确保与前面生成的内容保持连贯性
2. 确保情节发展合理，角色行为一致
3. 避免出现逻辑断层或情节冲突

已生成的章节大纲：
$previousContent
''';
          }
          
          // 统一的大纲生成系统提示词
          String systemPromptText = "你是一个专业的小说大纲创作助手，请根据用户的需求提供完整的情节大纲。大纲要包含清晰的起承转合，角色线索和主要冲突。确保每个章节之间情节连贯，角色发展合理。";
          
          // 统一的用户提示词
          String userPromptText = '''
${batchPrompt}
${contextPrompt}
请按照要求生成第$startChapter到第$endChapter章的详细大纲${startChapter > 1 ? "，确保与前面章节情节连贯" : ""}
''';
          
            if (onProgress != null) {
            onProgress('正在使用标准模式创建大纲...');
            }
            
          // 使用统一的生成方法
            await for (final chunk in _aiService.generateOutlineTextStream(
            systemPrompt: systemPromptText,
            userPrompt: userPromptText,
              maxTokens: _getMaxTokensForChapter(0) * 2,
              temperature: 0.7,
            novelTitle: title, // 传递小说标题
            )) {
              batchContent += chunk;
              if (onContent != null) {
                onContent(chunk);
              }
            }
        } catch (e) {
          print('大纲生成失败: $e');
          
          // 如果出错，使用备用方法
          if (onProgress != null) {
            onProgress('标准生成遇到问题，尝试备用方法...');
          }
          
          // 使用备用标准流式生成
          await for (final chunk in _aiService.generateOutlineTextStream(
            systemPrompt: batchPrompt,
            userPrompt: "请按照要求生成第$startChapter到第$endChapter章的详细大纲",
            maxTokens: _getMaxTokensForChapter(0) * 2,
            temperature: 0.7,
            novelTitle: title, // 传递小说标题
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
              onProgress('正在处理大纲批次...');
            }
            // 获取前一批次的最后部分作为参考上下文
            String previousContent = generatedChaptersBuffer.toString().trim();
            // 限制前一部分的长度，避免提示词过长
            if (previousContent.length > 2000) {
              previousContent = previousContent.substring(previousContent.length - 2000);
            }
            
            // 注释掉检查并修复连贯性的代码 - 使用langchain而不是自定义方法
            /*
            try {
              // 只有在LangChain服务可用时才使用它
              if (langchainService != null) {
                // 构建LangChain上下文
                final sessionId = langchainService.createNovelSession(
                  title: title,
                  genre: genre,
                  plotOutline: previousContent,
                  style: theme
                );
                
                // 生成修复内容
                final fixedContent = await langchainService.generateNovelContent(
                  sessionId: sessionId,
                  userMessage: '''
分析以下大纲内容，并修复可能的连贯性问题：

$processedBatch

请确保修复后的内容与前文 ($previousContent) 保持完美的情节连贯性，
不要添加任何额外评论或解释，直接返回修复后的内容。
''',
                  temperature: 0.5
                );
                
                // 删除会话（避免积累太多会话）
                await langchainService.deleteSession(sessionId);
                
                // 使用修复后的内容
                processedBatch = fixedContent;
              } else {
                // 如果LangChain不可用，使用原始方法
            processedBatch = await _ensureOutlineCoherence(processedBatch, previousContent);
              }
            } catch (e) {
              print('LangChain连贯性修复失败: $e');
              // 继续使用原始方法作为备用
              processedBatch = await _ensureOutlineCoherence(processedBatch, previousContent);
            }
            */
            
            // 移除连贯性检查的进度提示
            /*
            if (onProgress != null) {
              onProgress('大纲连贯性检查完成，继续生成...');
            }
            */
          }
        }
        
        // 添加到完整大纲，确保有明确的章节边界
        if (startChapter > 1) {
          // 确保在章节之间有足够的分隔
          if (!fullOutlineBuffer.toString().endsWith('\n\n')) {
            fullOutlineBuffer.writeln();
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

      // 格式化完整大纲，确保格式一致性
      String outlineContent = OutlineGeneration.formatOutline(fullOutlineBuffer.toString());
      
      // 验证所有章节都能被正确提取
      bool allChaptersValid = true;
      for (int i = 1; i <= totalChapters; i++) {
        final chapterOutline = _extractChapterOutline(outlineContent, i);
        if (chapterOutline.isEmpty || chapterOutline.contains('无法提取')) {
          print('警告：无法从大纲中提取第$i章内容');
          allChaptersValid = false;
        }
      }
      
      if (!allChaptersValid) {
        print('部分章节大纲提取失败，但将继续使用现有大纲');
      }
      
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
      final context = _buildChapterContextOld(
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
  // 不再使用动态token分配，统一使用7000 tokens
  int _getMaxTokensForChapter(int chapterNumber) {
    return 7000;  // 固定使用7000 tokens，确保能生成足够长度的内容
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
      
      // 将大纲作为第0章保存
      // novel.addOutlineAsChapter(); // 已取消此功能
      
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
          
          // 将大纲作为第0章保存
          // novel.addOutlineAsChapter(); // 已取消此功能
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
            number: i,
            totalChapters: totalChapters,
            theme: '本章要求',
            outline: novel.outline,
            novelConversationId: '_outline_${title.replaceAll(' ', '_')}',
            previousChapters: previousChapters,
            onProgress: (msg) => updateGenerationStatus(msg),
            onContent: (content) => updateRealtimeOutput(content),
            style: style,
            targetReaders: targetReader,
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
    
    // 首先尝试通过分段分析，查找所有可能的章节标记
    final chapterMatches = RegExp(r'第(\d+)章').allMatches(outline).toList();
    
    // 如果找到多个章节标记
    if (chapterMatches.isNotEmpty) {
      for (int i = 0; i < chapterMatches.length; i++) {
        final match = chapterMatches[i];
        final chapterNumber = int.parse(match.group(1)!);
        final start = match.start;
        final end = i < chapterMatches.length - 1 ? chapterMatches[i + 1].start : outline.length;
        
        // 提取章节文本
        final chapterText = outline.substring(start, end);
        
        // 提取标题
        String chapterTitle = '第$chapterNumber章';
        final titleLines = chapterText.split('\n');
        if (titleLines.isNotEmpty) {
          final firstLine = titleLines[0].trim();
          if (firstLine.contains('：')) {
            chapterTitle = firstLine.split('：')[1].trim();
          } else if (firstLine.contains(':')) {
            chapterTitle = firstLine.split(':')[1].trim();
          } else if (firstLine.length > 4) { // 假设"第X章"后有标题
            chapterTitle = firstLine.substring(3).trim();
          }
        }
        
        // 提取章节内容（除标题行外）
        final contentLines = chapterText.split('\n').skip(1).join('\n').trim();
        
        // 解析章节内容中的主要情节、次要情节等
        final Map<String, List<String>> contentSections = {
          'mainPlots': <String>[],
          'subPlots': <String>[],
          'characterDev': <String>[],
          'foreshadowing': <String>[],
        };
        
        // 当前处理的部分
        String currentSection = '';
        
        // 处理章节内容的每一行
        for (final line in contentLines.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          
          if (trimmed.startsWith('主要情节：') || trimmed.startsWith('主要情节:')) {
            currentSection = 'mainPlots';
            contentSections[currentSection]!.add(trimmed.replaceFirst(RegExp(r'主要情节[：:]'), '').trim());
          } else if (trimmed.startsWith('次要情节：') || trimmed.startsWith('次要情节:')) {
            currentSection = 'subPlots';
            contentSections[currentSection]!.add(trimmed.replaceFirst(RegExp(r'次要情节[：:]'), '').trim());
          } else if (trimmed.startsWith('人物发展：') || trimmed.startsWith('人物发展:')) {
            currentSection = 'characterDev';
            contentSections[currentSection]!.add(trimmed.replaceFirst(RegExp(r'人物发展[：:]'), '').trim());
          } else if (trimmed.startsWith('伏笔：') || trimmed.startsWith('伏笔:') || 
                     trimmed.startsWith('伏笔/悬念：') || trimmed.startsWith('伏笔/悬念:')) {
            currentSection = 'foreshadowing';
            contentSections[currentSection]!.add(trimmed.replaceFirst(RegExp(r'伏笔(?:/悬念)?[：:]'), '').trim());
          } else if (trimmed.startsWith('- ') && currentSection.isNotEmpty) {
            // 处理列表项
            contentSections[currentSection]!.add(trimmed.substring(2).trim());
          } else if (currentSection.isNotEmpty) {
            // 将非标记行添加到当前部分
            contentSections[currentSection]!.add(trimmed);
          }
        }
        
        // 创建章节计划
        chapterPlans[chapterNumber] = {
          'title': chapterTitle,
          'content': chapterText,
          'mainPlots': contentSections['mainPlots'],
          'subPlots': contentSections['subPlots'],
          'characterDev': contentSections['characterDev'],
          'foreshadowing': contentSections['foreshadowing'],
        };
      }
    }
    
    // 如果上述方法解析失败，尝试使用原始方法作为备份
    if (chapterPlans.isEmpty) {
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
    }
    
    return chapterPlans;
  }

  // 构建章节生成上下文 - 旧版本，用于兼容旧代码
  String _buildChapterContextOld({
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
    
    // 不再添加前序章节的详细内容，避免重复
    
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
      final context = _buildChapterContextOld(
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

  /// 生成单个章节
  Future<String> _generateChapter({
    required String title,
    required int number,
    required int totalChapters,
    required String genre,
    required String theme,
    required String outline,
    required String? novelConversationId,
    List<Chapter>? previousChapters,
    void Function(String)? onProgress,
    void Function(String)? onContent,
    String? style,
    String? targetReaders,
  }) async {
    try {
      // 增加调试输出，便于检查章节生成的上下文
      print('========== 章节生成调试信息 ==========');
      print('生成章节: 第$number章 / 共$totalChapters章');
      print('小说标题: $title');
      print('类型和主题: $genre - $theme');
      
      // 打印大纲摘要
      final outlinePreview = outline.length > 200 ? '${outline.substring(0, 200)}...(共${outline.length}字符)' : outline;
      print('大纲摘要: $outlinePreview');
      
      // 打印历史章节信息
      if (previousChapters != null && previousChapters.isNotEmpty) {
        print('历史章节数量: ${previousChapters.length}');
        for (var i = 0; i < previousChapters.length; i++) {
          final chapter = previousChapters[i];
          final contentPreview = chapter.content.length > 100 
              ? '${chapter.content.substring(0, 100)}...(共${chapter.content.length}字符)'
              : chapter.content;
          print('- 第${chapter.number}章: ${contentPreview}');
        }
            } else {
        print('无历史章节');
      }
      
      // 使用全局outline conversationId
      final conversationId = novelConversationId ?? '_outline_${title.replaceAll(' ', '_')}';
      print('使用会话ID: $conversationId');
      
      final systemPrompt = '''
你是一个创作能力极强的专业小说写手。请按照下面的要求创作高质量的章节内容：

1. 严格按照提供的大纲创作，确保内容符合要求，字数不低于3000字
2. 创作风格: ${style ?? _getRandomStyle()}
3. 直接进入正文创作，不要添加任何额外说明或标记
4. 请用非常简洁的描述方式描述剧情，冲突部分可以详细描写
5. 快节奏，多对话形式，以小见大
6. 不要使用小标题，不要加入旁白或解说，直接用流畅的叙述展开故事
7. 必须保持与前面章节的情节连续性，包括时间线、人物状态和关系发展，确保读者感受到自然的故事进展
''';
      
      // 从大纲中提取当前章节的信息
      var chapterOutline = _extractChapterOutline(outline, number);
      if (chapterOutline.isEmpty || chapterOutline.contains('无法提取')) {
        print('警告：无法从大纲中提取第$number章的信息，尝试备用方法...');
        
        // 尝试从整体大纲中提取相关内容作为备用
        String fallbackOutline = '';
        try {
          final lines = outline.split('\n');
          int relevantLineCount = 0;
          for (final line in lines) {
            if (line.contains('第$number章') || 
                line.contains('章节$number') || 
                line.contains('$number\\.') || 
                line.contains('$number、')) {
              fallbackOutline += '$line\n';
              relevantLineCount = 15; // 开始收集后面的15行
            } else if (relevantLineCount > 0) {
              fallbackOutline += '$line\n';
              relevantLineCount--;
            }
          }
          
          if (fallbackOutline.isNotEmpty) {
            print('使用备用方法找到了第$number章的相关内容');
        } else {
            print('备用方法也无法找到第$number章的内容，将使用整体大纲');
            fallbackOutline = '根据整体大纲，创作第$number章的内容。';
            }
          } catch (e) {
          print('备用提取方法失败: $e');
          fallbackOutline = '根据整体大纲，创作第$number章的内容。';
        }
        
        // 使用备用提取的内容
        chapterOutline = fallbackOutline;
      }
      
      // 构建用户提示词
      String chapterPrompt = '''
请为《$title》小说创作第$number章。

【本章节大纲】
$chapterOutline

【整体大纲参考】
${outline.length > 500 ? outline.substring(0, 500) + '...(省略部分)' : outline}

【创作要求】
- 类型：$genre
- 主题：$theme
${targetReaders != null ? '- 目标读者：$targetReaders\n' : ''}
- 章节编号：第$number章（共$totalChapters章）

请直接开始创作章节内容，字数不要低于3000字，不要包含任何额外的标记、解释或格式说明。
''';
      
      final buffer = StringBuffer();
      onProgress?.call('正在生成第$number章...');
      
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: chapterPrompt,
        maxTokens: 7000, // 固定使用7000 tokens
        temperature: 0.8,
        conversationId: conversationId, // 使用全局对话ID
      )) {
        // 检查是否暂停
        await _checkPause();
        
        buffer.write(chunk);
        if (onContent != null) {
          onContent(chunk);
        }
      }
      
      // 清理生成的内容
      String generatedContent = _cleanContent(buffer.toString());
      
      // 检查连贯性
      if (previousChapters != null && previousChapters.isNotEmpty && number > 1) {
        onProgress?.call('正在检查第$number章与前文的连贯性...');
        generatedContent = await _ensureChapterCoherence(
          generatedContent: generatedContent,
          previousChapters: previousChapters,
          outline: outline,
          chapterNumber: number,
          onProgress: onProgress,
        );
      }
      
      onProgress?.call('第$number章生成完成');
      print('第$number章生成完成');
      
      return generatedContent;
    } catch (e) {
      print('第$number章生成失败: $e');
      throw Exception('生成章节失败: $e');
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
        final chapterModelConfig = _apiConfig.getChapterModel();
        print('使用章节专用模型: ${chapterModelConfig.name}');
        
        await for (final chunk in _aiService.generateTextStream(
          systemPrompt: MasterPrompts.basicPrinciples,
          userPrompt: prompt,
          temperature: temperature,
          repetitionPenalty: repetitionPenalty,
          maxTokens: chapterModelConfig.maxTokens,
          topP: chapterModelConfig.topP,
          conversationId: novelTitle != null ? '_outline_${novelTitle.replaceAll(' ', '_')}' : null,
          specificModelConfig: chapterModelConfig,
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
      
      // 添加当前章节大纲和内容
      final currentChapterOutline = _extractChapterOutline(outline, chapterNumber);
      buffer.writeln('【当前章节大纲】');
      buffer.writeln(currentChapterOutline);
      buffer.writeln();
      
      buffer.writeln('【生成的章节内容】');
      buffer.writeln(_truncateContent(generatedContent, 2000)); // 截断内容以避免提示词过长
      buffer.writeln();
      
      buffer.writeln('【连贯性检查结果】');
      buffer.writeln('这个章节内容是否与大纲要求相符？是否有需要修正的逻辑问题或情节冲突？');
      
      // 生成连贯性分析
      String analysisResult = await _generateWithAI(
        buffer.toString(),
        temperature: 0.3, // 使用较低的温度以获得更客观的分析
        repetitionPenalty: 1.0,
        useOutlineModel: true,
      );
      
      // 如果分析结果表明存在问题，则修复
      if (_hasCoherenceIssues(analysisResult)) {
        onProgress?.call('发现连贯性问题，正在修复...');
        
          // 构建修复提示词
        final fixBuffer = StringBuffer();
        fixBuffer.writeln('【当前章节大纲】');
        fixBuffer.writeln(currentChapterOutline);
        fixBuffer.writeln();
        
        fixBuffer.writeln('【现有章节内容】');
        fixBuffer.writeln(_truncateContent(generatedContent, 2000));
        fixBuffer.writeln();
        
        fixBuffer.writeln('【连贯性问题分析】');
        fixBuffer.writeln(analysisResult);
        fixBuffer.writeln();
        
        fixBuffer.writeln('【修复要求】');
        fixBuffer.writeln('请修改上述章节内容，解决连贯性问题，使其符合大纲要求，并确保逻辑自洽。');
        fixBuffer.writeln('请直接输出修改后的完整章节内容，不要包含任何解释或分析。');
        
        // 生成修复后的内容
        String fixedContent = await _generateWithAI(
          fixBuffer.toString(),
          temperature: 0.7,
          repetitionPenalty: 1.2,
        );
        
        onProgress?.call('章节连贯性修复完成');
        
        return _cleanGeneratedContent(fixedContent);
      }
      
      onProgress?.call('章节连贯性检查完成，未发现问题');
      
      return generatedContent;
        } catch (e) {
      print('章节连贯性检查失败: $e');
      // 如果检查失败，返回原始内容
      return generatedContent;
    }
  }

  // 从大纲中提取特定章节的内容
  String _extractChapterOutline(String outline, int chapterNumber) {
    // 使用多种正则表达式模式匹配不同格式的章节
    final patterns = [
      // 标准格式：第N章：标题
      RegExp(r'第' + chapterNumber.toString() + r'章[:：].*?(?=第' + (chapterNumber + 1).toString() + r'章|$)', dotAll: true),
      // 无冒号格式：第N章 标题
      RegExp(r'第' + chapterNumber.toString() + r'章\s.*?(?=第' + (chapterNumber + 1).toString() + r'章|$)', dotAll: true),
      // 仅数字格式：N. 标题或N、标题
      RegExp(r'\b' + chapterNumber.toString() + r'[\.、].*?(?=\b' + (chapterNumber + 1).toString() + r'[\.、]|$)', dotAll: true),
    ];
    
    // 尝试所有正则表达式模式
    for (final pattern in patterns) {
      final match = pattern.firstMatch(outline);
    if (match != null) {
        String result = match.group(0) ?? '';
        print('成功使用正则表达式提取第$chapterNumber章大纲');
        return result;
      }
    }
    
    // 如果正则匹配失败，尝试使用解析方法
    final chapterPlans = _parseOutline(outline);
    if (chapterPlans.containsKey(chapterNumber)) {
      print('使用解析方法成功提取第$chapterNumber章大纲');
      return chapterPlans[chapterNumber]?['content'] ?? '';
    }
    
    // 记录失败信息以便调试
    final previewLength = outline.length > 300 ? 300 : outline.length;
    print('无法提取第$chapterNumber章大纲，大纲前300个字符: ${outline.substring(0, previewLength)}...');
    
    return '无法提取第$chapterNumber章的大纲内容';
  }

  /// 重新生成章节内容，与之前版本不同的写法和视角
  Future<String> _regenerateChapter({
    required String title,
    required int number,
    required int totalChapters,
    required String genre,
    required String theme,
    required String outline,
    required List<Chapter> previousChapters,
    required void Function(String)? onProgress,
    required void Function(String)? onContent,
    String? style,
    String? targetReaders,
  }) async {
    try {
      // 随机选择一种创作风格，让重生成的内容有变化
      style = style ?? _getRandomStyle();
      
      final systemPrompt = '''
你是一个创作能力极强的专业小说写手。现在需要重新创作已有章节，要求风格和表达方式与之前不同。请注意：

1. 章节大纲和主要情节必须保持一致，但表达方式和写法要有明显差异
2. 创作风格: $style
3. 使用不同于之前的场景描写和对话方式，但确保符合大纲要求
4. 直接进入正文创作，不要添加任何额外说明或标记
5. 请用非常简洁的描述方式描述剧情，冲突部分可以详细描写
6. 快节奏，多对话形式，以小见大，人物对话格式：'xxxxx'某某说道
7. 不要使用小标题，不要加入旁白或解说，直接用流畅的叙述展开故事
8. 请直接撰写章节内容，不要添加任何前导说明或总结
''';
      
      // 构建章节提示词
      final userPrompt = '''
请为《$title》小说重新创作第$number章。

【本章节大纲】
${_extractChapterOutline(outline, number)}

【创作要求】
- 类型：$genre
- 主题：$theme
${targetReaders != null ? '- 目标读者：$targetReaders\n' : ''}
- 章节编号：第$number章（共$totalChapters章）

请直接开始创作章节内容，不要包含任何额外的标记、解释或格式说明。
''';
      
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
        maxTokens: 7000, // 固定使用7000 tokens
        temperature: 0.85,  // 增加温度以获得更多变化
        conversationId: regenerateConversationId, // 使用专门的重生成对话ID
      )) {
        // 检查是否暂停
        await _checkPause();
        
        // 更新内容
        buffer.write(chunk);
        
        // 调用回调函数
        if (onContent != null) {
          onContent(chunk);
        }
      }
      
      String newContent = _cleanContent(buffer.toString());
      
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

  /// 清理生成的内容，去除前缀和后缀
  String _cleanContent(String content) {
    // 移除章节标题前缀
    final titlePrefixPattern = RegExp(r'^第\d+章[：:][^\n]*\n+');
    content = content.replaceFirst(titlePrefixPattern, '').trim();
    
    // 移除可能的AI标识和说明
    content = content.replaceAll(RegExp(r'^(AI:|ChatGPT:)'), '').trim();
    
    // 移除末尾可能的AI署名等
    content = content.replaceAll(RegExp(r'由AI生成$|AI助手$|AI写手$'), '').trim();
    
    return content;
  }

  // 检查连贯性分析结果是否表明存在问题
  bool _hasCoherenceIssues(String analysisResult) {
    // 检查分析结果中是否包含表示问题的关键词
    final problemKeywords = [
      '不符合', '不一致', '冲突', '矛盾', '问题', 
      '缺乏', '不连贯', '脱节', '不合理', '缺失',
      '偏离', '不符', '错误', '混乱', '需要修改',
      '应该调整', '建议修改', '不匹配'
    ];
    
    final lowerResult = analysisResult.toLowerCase();
    
    for (final keyword in problemKeywords) {
      if (lowerResult.contains(keyword)) {
        return true;
      }
    }
    
    // 检查是否包含明确表示无问题的关键词
    final noIssueKeywords = [
      '符合大纲', '连贯性良好', '没有问题', '逻辑清晰',
      '内容合理', '符合要求', '完全符合', '保持了一致性'
    ];
    
    for (final keyword in noIssueKeywords) {
      if (lowerResult.contains(keyword) && !lowerResult.contains('不' + keyword)) {
        return false;
      }
    }
    
    // 默认情况下，如果没有明确指出问题或明确表示无问题，则认为存在问题
    return true;
  }
  
  // 截断内容，避免提示词过长
  String _truncateContent(String content, int maxLength) {
    if (content.length <= maxLength) {
      return content;
    }
    
    final halfLength = maxLength ~/ 2;
    return content.substring(0, halfLength) + 
           '\n...\n[内容过长，中间部分省略]\n...\n' + 
           content.substring(content.length - halfLength);
  }

  // 批量生成多个章节
  Future<List<Chapter>> generateChapters({
    required String title,
    required String genre,
    required String theme,
    required int startChapter,
    required int endChapter,
    required int totalChapters,
    required String outline,
    List<Chapter>? previousChapters,
    void Function(String)? onProgress,
    void Function(String)? onContent,
    String? style,
    String? targetReaders,
  }) async {
    final List<Chapter> chapters = [];
    
    // 使用全局的outline conversationId
    final String novelConversationId = '_outline_${title.replaceAll(' ', '_')}';
    
    for (int i = startChapter; i <= endChapter; i++) {
      if (onProgress != null) {
        onProgress('正在生成第$i章...');
      }
      
      // 从大纲中提取章节标题
      final chapterTitle = _extractChapterTitle(outline, i);
      
      try {
        // 使用新的_generateChapter方法生成章节
        final content = await _generateChapter(
          title: title,
          genre: genre,
          number: i,
          totalChapters: totalChapters,
          theme: theme,
          outline: outline,
          novelConversationId: novelConversationId,
          previousChapters: previousChapters,
          onProgress: onProgress,
          onContent: onContent,
          style: style,
          targetReaders: targetReaders,
        );
        
        // 创建章节对象
        final chapter = Chapter(
          number: i,
          title: chapterTitle.isNotEmpty ? chapterTitle : '第$i章',
          content: content,
        );
        
        chapters.add(chapter);
        
        // 将已生成的章节添加到previousChapters列表中，以便后续章节生成时使用
        if (previousChapters != null) {
          previousChapters.add(chapter);
        }
        
        // 等待一段时间再继续生成下一章，避免API速率限制
        if (i < endChapter) {
          await Future.delayed(Duration(seconds: 1));
        }
      } catch (e) {
        print('生成第$i章失败: $e');
        if (onProgress != null) {
          onProgress('生成第$i章失败: $e');
        }
        
        // 如果是第一章生成失败，则抛出异常
        if (i == startChapter) {
          throw Exception('生成第$i章失败: $e');
        }
        
        // 其他章节生成失败，则添加一个占位章节
        chapters.add(Chapter(
          number: i,
          title: chapterTitle.isNotEmpty ? chapterTitle : '第$i章',
          content: '本章节生成失败，请稍后重试。\n\n错误信息: $e',
        ));
      }
    }
    
    return chapters;
  }

  // 重新生成指定章节的内容
  Future<String> regenerateChapter({
    required String title,
    required int number,
    required int totalChapters,
    required String genre,
    required String theme,
    required String outline,
    required List<Chapter> previousChapters,
    void Function(String)? onProgress,
    void Function(String)? onContent,
    String? style,
    String? targetReaders,
  }) async {
    try {
      print('开始重新生成第$number章');
      
      // 使用与原始章节生成相同的对话ID，确保历史记录连续性
      final conversationId = '_outline_${title.replaceAll(' ', '_')}';
      print('使用相同全局会话ID: $conversationId 保持历史连贯性');
      
      final systemPrompt = '''
你是一个创作能力极强的专业小说写手。请按照下面的要求创作高质量的章节内容：

1. 严格按照提供的大纲创作，确保内容符合要求
2. 内容要连贯丰富，人物刻画生动，情节发展合理
3. 创作风格: ${style ?? _getRandomStyle()}
4. 直接进入正文创作，不要添加任何额外说明或标记
5. 请用非常简洁的描述方式描述剧情，冲突部分可以详细描写
6. 快节奏，多对话形式，以小见大
7. 人物对话格式：'xxxxx'某某说道
8. 不要使用小标题，不要加入旁白或解说，直接用流畅的叙述展开故事
9. 必须保持与前面章节的情节连续性，包括时间线、人物状态和关系发展，确保读者感受到自然的故事进展
''';
      
      // 从大纲中提取当前章节的信息
      final chapterOutline = _extractChapterOutline(outline, number);
      if (chapterOutline.isEmpty) {
        throw Exception('无法从大纲中找到第$number章的信息');
      }
      
      // 构建用户提示词
      String userPrompt = '''
请为《$title》小说重新创作第$number章。需要不同的表达方式但保持相同的情节发展。

【本章节大纲】
$chapterOutline

【创作要求】
- 类型：$genre
- 主题：$theme
${targetReaders != null ? '- 目标读者：$targetReaders\n' : ''}
- 章节编号：第$number章（共$totalChapters章）

请直接开始创作章节内容，不要包含任何额外的标记、解释或格式说明。
''';
      
      // 使用流式生成
      final buffer = StringBuffer();
      
      onProgress?.call('正在重新生成第$number章...');
      
      // 确保回调函数被调用
      if (onContent != null) {
        onContent('\n开始重新生成第$number章内容...\n');
      }
      
      // 重新生成时使用与原始生成相同的会话ID，确保历史记录连续性
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 7000, // 固定使用7000 tokens
        temperature: 0.85,  // 增加温度以获得更多变化
        conversationId: conversationId, // 使用全局会话ID确保历史记录连续性
      )) {
        // 检查是否暂停
        await _checkPause();
        
        // 更新内容
        buffer.write(chunk);
        
        // 调用回调函数
        if (onContent != null) {
          onContent(chunk);
        }
      }
      
      String newContent = _cleanContent(buffer.toString());
      
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
} 