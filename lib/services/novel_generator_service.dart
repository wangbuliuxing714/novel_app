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

  // 添加新的成员变量
  late Function(String) _updateRealtimeOutput;
  late Function(String) _updateGenerationStatus;
  late Function(double) _updateGenerationProgress;

  NovelGeneratorService(
    this._aiService, 
    this._apiConfig, 
    this._cacheService,
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
    void Function(String)? onProgress,
    void Function(String)? onContent,
    bool isShortNovel = false,
    int wordCount = 15000,
  }) async {
    try {
      if (isShortNovel) {
        _updateProgress("正在生成短篇小说大纲...");
      } else {
        _updateProgress("正在生成大纲...");
      }
      
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final outlinePrompt = promptPackageController.getCurrentPromptContent('outline');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(targetReaders);
      
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
      
      // 构建提示词
      final prompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${outlinePrompt.isNotEmpty ? outlinePrompt + '\n\n' : ''}
${targetReaderPrompt.isNotEmpty ? targetReaderPrompt + '\n\n' : ''}
${outlineFormatPrompt}
''';
      
      // 一次性生成所有章节的大纲
      String outlineContent = '';
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: prompt,
        userPrompt: outlinePrompt,
        maxTokens: _getMaxTokensForChapter(0) * 2, // 增加token限制以容纳完整大纲
        temperature: 0.7,
      )) {
        outlineContent += chunk;
        if (onContent != null) {
          onContent(chunk);
        }
      }

      // 格式化大纲
      outlineContent = OutlineGeneration.formatOutline(outlineContent);
      
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
      rethrow;
    }
  }

  Future<Chapter> generateChapter({
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
      // 清理之前可能失败的缓存
      clearFailedGenerationCache();
      
      // 检查是否有缓存
      final chapterKey = 'chapter_${title}_$number';
      final cachedContent = await _checkCache(chapterKey);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        print('使用缓存的章节内容: $chapterKey');
        return Chapter(
          number: number,
          title: _extractChapterTitle(cachedContent, number),
          content: cachedContent,
        );
      }
      
      // 解析大纲，提取当前章节的要求
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
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final chapterPrompt = promptPackageController.getCurrentPromptContent('chapter');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(targetReaders);
      
      // 获取章节标题
      final chapterTitle = chapterPlans[number]?['title'] ?? '第$number章';
      
      // 设置当前风格
      style = _determineStyle(number, totalChapters, null);
      
      // 构建提示词
      final systemPrompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${targetReaderPrompt.isNotEmpty ? targetReaderPrompt + '\n\n' : ''}
${ChapterGeneration.getSystemPrompt(style)}
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
      String currentParagraph = '';
      
      onProgress?.call('正在生成第$number章...');
      
      // 确保回调函数被调用
      if (onContent != null) {
        onContent('\n开始生成第$number章内容...\n');
      }
      
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: _getMaxTokensForChapter(number),
        temperature: _getTemperatureForChapter(number, totalChapters),
      )) {
        // 检查是否暂停
        await _checkPause();
        
        // 更新内容
        final cleanedChunk = ChapterGeneration.formatChapter(chunk);
        buffer.write(cleanedChunk);
        currentParagraph += cleanedChunk;
        
        // 调用回调函数
        if (onContent != null) {
          onContent(cleanedChunk);
        }
        
        // 如果遇到段落结束，处理当前段落
        if (cleanedChunk.contains('\n\n')) {
          final parts = currentParagraph.split('\n\n');
          currentParagraph = parts.last;
          
          // 处理完整段落
          for (var i = 0; i < parts.length - 1; i++) {
            final paragraph = parts[i];
            if (paragraph.trim().isNotEmpty) {
              // 检查段落重复
              final processedParagraph = await _handleParagraphGeneration(
                paragraph,
                title: title,
                chapterNumber: number,
                outline: outline,
                context: {
                  'currentContext': buffer.toString(),
                  'chapterTheme': theme,
                  'style': style,
                },
              );
              
              // 如果段落被修改，更新输出
              if (processedParagraph != paragraph && onContent != null) {
                onContent('\n[检测到重复内容，已修改]\n');
              }
            }
          }
        }
      }
      
      // 缓存生成的内容
      await _cacheContent(chapterKey, buffer.toString());
      
      return Chapter(
        number: number,
        title: chapterTitle,
        content: buffer.toString(),
      );
    } catch (e) {
      print('生成章节失败: $e');
      // 重试
      if (e.toString().contains('timeout') || e.toString().contains('network')) {
        print('网络错误，尝试重新生成章节');
        return generateChapter(
          title: title,
          number: number,
          outline: outline,
          previousChapters: previousChapters,
          totalChapters: totalChapters,
          genre: genre,
          theme: theme,
          targetReaders: targetReaders,
          onProgress: onProgress,
          onContent: onContent,
        );
      }
      
      return Chapter(
        number: number,
        title: '第$number章',
        content: '生成失败: $e',
      );
    }
  }

  double _getTemperatureForChapter(int number, int totalChapters) {
    final progress = number / totalChapters;
    if (progress < 0.2) return 0.8;  // 提高开始阶段的创造性
    if (progress < 0.4) return 0.85;
    if (progress < 0.7) return 0.9;
    return 0.85;  // 提高结尾阶段的创造性
  }

  int _getMaxTokensForChapter(int chapterNumber) {
    final apiConfig = Get.find<ApiConfigController>();
    final model = apiConfig.getCurrentModel();
    // 大纲生成使用较小的token限制
    if (chapterNumber == 0) {
      return 2000;  // 大纲生成使用固定值
    }
    // 章节生成使用设置的token限制
    return model.maxTokens;
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
    // 简单的摘要生成逻辑，可以根据需要优化
    final sentences = content.split('。');
    if (sentences.length <= 3) return content;
    
    return sentences.take(3).join('。') + '。';
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
      // 原有的长篇小说生成逻辑
      // 创建一个默认小说对象作为返回值
      Novel novel = Novel(
          title: title,
        genre: genres.join(','),
        outline: '',
        content: '',
        chapters: [],
        createdAt: DateTime.now(),
      );
      
      updateRealtimeOutput('长篇小说生成功能尚未更新，请使用短篇小说模式。\n');
      updateGenerationStatus('生成结束');
      
      // 确保返回非空Novel对象
      return novel;
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
    List<CharacterCard>? characters,
    String? background,
    List<String>? specialRequirements,
  }) {
    final buffer = StringBuffer();
    
    // 添加角色信息
    if (characters != null && characters.isNotEmpty) {
      buffer.writeln('【主要角色】');
      for (var character in characters) {
        buffer.writeln('${character.name}：');
        if (character.gender != null && character.gender!.isNotEmpty) 
          buffer.writeln('- 性别：${character.gender}');
        if (character.age != null && character.age!.isNotEmpty) 
          buffer.writeln('- 年龄：${character.age}');
        if (character.personalityTraits != null && character.personalityTraits!.isNotEmpty) 
          buffer.writeln('- 性格：${character.personalityTraits}');
        if (character.background != null && character.background!.isNotEmpty) 
          buffer.writeln('- 背景：${character.background}');
        if (character.motivation != null && character.motivation!.isNotEmpty) 
          buffer.writeln('- 动机：${character.motivation}');
        buffer.writeln();
      }
    }
    
    // 添加背景信息
    if (background != null && background.isNotEmpty) {
      buffer.writeln('【故事背景】');
      buffer.writeln(background);
      buffer.writeln();
    }
    
    // 添加特殊要求
    if (specialRequirements != null && specialRequirements.isNotEmpty) {
      buffer.writeln('【特殊要求】');
      for (var requirement in specialRequirements) {
        buffer.writeln('- $requirement');
      }
      buffer.writeln();
    }
    
    // 现有代码...
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
      buffer.writeln('【前序章节摘要】');
      for (var i = previousChapters.length - 1; i >= 0 && i >= previousChapters.length - 2; i--) {
        buffer.writeln('${previousChapters[i].title}:');
        buffer.writeln(_generateChapterSummary(previousChapters[i].content));
        buffer.writeln();
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
    required int chapterNumber,
    required String outline,
    required List<String> previousChapters,
    required int totalChapters,
    required String genre,
    required String theme,
    required String style,
    required String targetReaders,
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final chapterPrompt = promptPackageController.getCurrentPromptContent('chapter');
      
      // 构建提示词
      final prompt = '''
${masterPrompt.isNotEmpty ? masterPrompt + '\n\n' : ''}
${chapterPrompt.isNotEmpty ? chapterPrompt + '\n\n' : ''}
请根据以下信息创作小说章节内容：

小说标题：$title
小说类型：$genre
小说大纲：$outline
当前章节：第$chapterNumber章
章节大纲：$outline

要求：
1. 创作一个生动、引人入胜的章节内容，符合章节大纲的要求
2. 确保章节内容与整体故事大纲保持一致
3. 在章节中实现至少一种期待感类型（展现价值型或矛盾冲突型）
4. 如果是展现价值型期待感，请确保：
   - 清晰展示角色的能力或独特个性
   - 提供一个发挥能力的空间或背景
   - 展示对这个能力的迫切需求
   - 埋没角色的价值（受到轻视、压迫、冷落等）
5. 如果是矛盾冲突型期待感，请确保：
   - 构建相互依存的矛盾关系
   - 一个能力与一个不恰当的规则形成矛盾
   - 一个欲望与一个压力形成矛盾
   - 两个矛盾之间互相影响，形成期待
6. 章节长度控制在3000-5000字之间
7. 注重人物对话和内心活动的描写，使人物形象更加丰满
8. 场景描写要生动形象，有代入感
9. 章节结尾要留有悬念，引导读者继续阅读下一章

请直接输出章节内容，不需要包含章节标题。
''';

      // 检查缓存
      final chapterKey = '${title}_chapter_$chapterNumber';
      final cachedContent = await _checkCache(chapterKey);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        print('使用缓存的章节内容: $chapterKey');
        if (onContent != null) {
          onContent('\n[使用缓存的内容]\n');
          // 分段发送缓存内容，模拟实时生成效果
          const chunkSize = 100;
          for (var i = 0; i < cachedContent.length; i += chunkSize) {
            final end = (i + chunkSize < cachedContent.length) ? i + chunkSize : cachedContent.length;
            final chunk = cachedContent.substring(i, end);
            onContent(chunk);
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
        return cachedContent;
      }

      // 准备生成章节内容
      onProgress?.call('正在生成第$chapterNumber章...');
      
      // 确保回调函数被调用
      if (onContent != null) {
        onContent('\n开始生成第$chapterNumber章内容...\n');
      }
      
      // 获取章节规划和上下文
      final chapterContext = _buildChapterContext(
        outline: outline,
        previousChapters: previousChapters.map((content) => 
          Chapter(number: 0, title: '', content: content)
        ).toList(),
        currentNumber: chapterNumber,
        totalChapters: totalChapters,
      );
      
      // 生成章节内容
      final systemPrompt = ChapterGeneration.getSystemPrompt(style);
      
      final userPrompt = ChapterGeneration.getChapterPrompt(
        title: title,
        chapterNumber: chapterNumber,
        totalChapters: totalChapters,
        outline: outline,
        previousChapters: previousChapters.map((content) => Chapter(
          number: 0, // 这里的number不重要，因为我们只需要content
          title: '',
          content: content,
        )).toList(),
        genre: genre,
        theme: theme,
        style: style,
        targetReaders: targetReaders,
      );
      
      // 使用流式生成
      final buffer = StringBuffer();
      String currentParagraph = '';
      
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: _getMaxTokensForChapter(chapterNumber),
        temperature: _getTemperatureForChapter(chapterNumber, totalChapters),
      )) {
        // 检查是否暂停
        await _checkPause();
        
        // 更新内容
        final cleanedChunk = ChapterGeneration.formatChapter(chunk);
        buffer.write(cleanedChunk);
        currentParagraph += cleanedChunk;
        
        // 调用回调函数
        if (onContent != null) {
          onContent(cleanedChunk);
        }
        
        // 如果遇到段落结束，处理当前段落
        if (cleanedChunk.contains('\n\n')) {
          final parts = currentParagraph.split('\n\n');
          currentParagraph = parts.last;
          
          // 处理完整段落
          for (var i = 0; i < parts.length - 1; i++) {
            final paragraph = parts[i];
            if (paragraph.trim().isNotEmpty) {
              // 检查段落重复
              final processedParagraph = await _handleParagraphGeneration(
                paragraph,
                title: title,
                chapterNumber: chapterNumber,
                outline: outline,
                context: {
                  'currentContext': buffer.toString(),
                  'chapterTheme': theme,
                  'style': style,
                },
              );
              
              // 如果段落被修改，更新输出
              if (processedParagraph != paragraph && onContent != null) {
                onContent('\n[检测到重复内容，已修改]\n');
              }
            }
          }
        }
      }

      return buffer.toString();
    } catch (e) {
      print('生成章节失败: $e');
      rethrow;
    }
  }

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
  }) async {
    try {
      String response = '';
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: MasterPrompts.basicPrinciples,
        userPrompt: prompt,
        temperature: temperature,
        repetitionPenalty: repetitionPenalty,
        maxTokens: _apiConfig.getCurrentModel().maxTokens,
        topP: _apiConfig.getCurrentModel().topP,
      )) {
        response += chunk;
      }
      return response;
    } catch (e) {
      print('生成失败: $e');
      rethrow;
    }
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

  // 添加获取上次生成进度的方法
  Future<Map<String, dynamic>?> _getLastGenerationProgress(String title) async {
    final box = await Hive.openBox('generation_progress');
    final progress = box.get('last_generation');
    if (progress != null && progress['title'] == title) {
      return Map<String, dynamic>.from(progress);
    }
    return null;
  }

  // 添加清除生成进度的方法
  Future<void> clearGenerationProgress() async {
    final box = await Hive.openBox('generation_progress');
    await box.delete('last_generation');
  }

  // 添加继续生成的方法
  Future<Novel> continueGeneration({
    required String title,
    required String genre,
    required String theme,
    required String targetReaders,
    required int totalChapters,
    String background = '',
    String style = '',
    List<String>? specialRequirements,
    void Function(String)? onProgress,
    void Function(String)? onContent,
    void Function(int, String, String)? onChapterComplete,
    bool isShortNovel = false,
    int wordCount = 15000,
  }) async {
    final progress = await _getLastGenerationProgress(title);
    if (progress == null) {
      throw Exception('未找到上次的生成进度');
    }

    final outline = progress['outline'] as String;
    final savedChapters = (progress['chapters'] as List)
        .map((c) => Chapter.fromJson(Map<String, dynamic>.from(c)))
        .toList();

    onProgress?.call('正在从上次的进度继续生成...');
    onContent?.call('已恢复大纲和${savedChapters.length}个章节\n\n');

    // 从上次的进度继续生成
    final novel = Novel(
      title: title,
      genre: genre,
      outline: outline,
      content: '',
      chapters: savedChapters,
      createdAt: DateTime.now(),
    );

    // 继续生成剩余的章节
    for (var i = savedChapters.length + 1; i <= totalChapters; i++) {
      await _checkPause();
      onProgress?.call('正在生成第$i章...');
      
      final chapterContent = await _generateChapter(
        title: title,
        genre: genre,
        theme: theme,
        outline: outline,
        chapterNumber: i,
        totalChapters: totalChapters,
        previousChapters: savedChapters,
        onContent: onContent,
      );

      final chapter = Chapter(
        number: i,
        title: '第$i章',
        content: chapterContent,
      );
      
      novel.chapters.add(chapter);
      
      // 保存当前进度
      await _saveGenerationProgress(
        title: title,
        genre: genre,
        theme: theme,
        targetReaders: targetReaders,
        totalChapters: totalChapters,
        outline: outline,
        chapters: novel.chapters,
      );
    }

    // 生成完成后清除进度
    await clearGenerationProgress();
    return novel;
  }

  // 暂停生成
  void pauseGeneration() {
    if (!_isPaused.value) {
      _isPaused.value = true;
      if (_pauseCompleter == null || _pauseCompleter!.isCompleted) {
        _pauseCompleter = Completer<void>();
      }
    }
  }

  // 继续生成
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

  Future<String> _generateChapter({
    required String title,
    required String genre,
    required String theme,
    required String outline,
    required int chapterNumber,
    required int totalChapters,
    required List<Chapter> previousChapters,
    void Function(String)? onContent,
  }) async {
    try {
      // 将之前的章节转换为字符串列表
      final previousChapterContents = previousChapters
          .map((chapter) => chapter.content)
          .toList();

      final chapterContent = await _generateChapterContent(
        title: title,
        chapterNumber: chapterNumber,
        outline: outline,
        previousChapters: previousChapterContents,
        totalChapters: totalChapters,
        genre: genre,
        theme: theme,
        style: _determineStyle(chapterNumber, totalChapters, null),
        targetReaders: targetReaders,
        onProgress: null,
        onContent: onContent,
      );

      return chapterContent;
    } catch (e) {
      print('生成章节失败: $e');
      rethrow;
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
    // 尝试根据段落或明确的章节分隔符来分割大纲
    final parts = <String>[];
    
    // 首先检查是否已经有明确的五部分结构
    final sectionMatches = RegExp(r'[A-E][.、][\s\S]*?(?=[A-E][.、]|$)').allMatches(outline);
    if (sectionMatches.length >= 5) {
      for (final match in sectionMatches.take(5)) {
        parts.add(match.group(0)!.trim());
      }
      return parts;
    }
    
    // 尝试按数字标题分割
    final numberMatches = RegExp(r'\d+[.、][\s\S]*?(?=\d+[.、]|$)').allMatches(outline);
    if (numberMatches.length >= 5) {
      final allParts = numberMatches.map((m) => m.group(0)!.trim()).toList();
      
      // 将所有部分平均分配到五个部分中
      final totalParts = allParts.length;
      final partsPerSection = totalParts / 5;
      
      for (int i = 0; i < 5; i++) {
        final startIdx = (i * partsPerSection).floor();
        final endIdx = math.min(((i + 1) * partsPerSection).floor(), totalParts);
        parts.add(allParts.sublist(startIdx, endIdx).join('\n\n'));
      }
      
      return parts;
    }
    
    // 如果没有明确的分隔标记，则按段落平均分配
    final paragraphs = outline.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.length >= 5) {
      final totalParagraphs = paragraphs.length;
      final paragraphsPerPart = totalParagraphs / 5;
      
      for (int i = 0; i < 5; i++) {
        final startIdx = (i * paragraphsPerPart).floor();
        final endIdx = math.min(((i + 1) * paragraphsPerPart).floor(), totalParagraphs);
        parts.add(paragraphs.sublist(startIdx, endIdx).join('\n\n'));
      }
      
      return parts;
    }
    
    // 如果段落太少，则强制分成五部分
    if (paragraphs.length < 5) {
      // 确保至少有五个元素
      while (paragraphs.length < 5) {
        paragraphs.add('继续发展故事');
      }
      return paragraphs.sublist(0, 5);
    }
    
    // 应该不会到这里，但为了安全起见
    return List.generate(5, (index) => '第${index + 1}部分');
  }
} 