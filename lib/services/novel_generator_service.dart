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

  NovelGeneratorService(
    this._aiService, 
    this._apiConfig, 
    this._cacheService,
    {this.onProgress}
  );

  // 获取当前生成状态的getter
  int get currentGeneratingChapter => _currentGeneratingChapter.value;
  bool get isGenerating => _isGenerating.value;
  bool get isPaused => _isPaused.value;  // 添加暂停状态getter
  String get lastError => _lastError.value;
  List<Chapter> get generatedChapters => _generatedChapters;
  String get currentNovelTitle => _currentNovelTitle.value;
  String get currentNovelOutline => _currentNovelOutline.value;

  void _updateProgress(String message) {
    onProgress?.call(message);
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
  }) async {
    try {
      _updateProgress("正在生成大纲...");
      
      // 获取提示词包内容
      final promptPackageController = Get.find<PromptPackageController>();
      final masterPrompt = promptPackageController.getCurrentPromptContent('master');
      final outlinePrompt = promptPackageController.getCurrentPromptContent('outline');
      final targetReaderPrompt = promptPackageController.getTargetReaderPromptContent(targetReaders);
      
      // 根据目标读者选择不同的提示词
      String outlineFormatPrompt = '';
      if (targetReaders == '女性向') {
        // 使用女性向提示词
        outlineFormatPrompt = FemalePrompts.getOutlinePrompt(title, genre, theme, totalChapters);
      } else {
        // 默认使用男性向提示词
        outlineFormatPrompt = MalePrompts.getOutlinePrompt(title, genre, theme, totalChapters);
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
        onProgress('已生成完整大纲');
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
    required String genre,
    required String theme,
    required String targetReaders,
    required int totalChapters,
    String background = '',
    String style = '',
    List<String>? specialRequirements,
    bool continueGeneration = false,
    void Function(String)? onProgress,
    void Function(String)? onContent,
    void Function(int, String, String)? onChapterComplete,
  }) async {
    try {
      _isGenerating.value = true;
      _currentNovelTitle.value = title;
      
      // 清除之前的缓存，确保新的生成过程不受影响
      if (!continueGeneration) {
        print('开始新小说生成，清除之前的缓存');
        clearFailedGenerationCache();
        _generatedParagraphs.clear();
      }
      
      // 确保回调函数被调用
      if (onContent != null) {
        onContent('准备生成小说: $title\n');
      }
      
      // 如果是继续生成，则从上次的进度继续
      if (continueGeneration) {
        final progress = await _getLastGenerationProgress(title);
        if (progress != null) {
          return await this.continueGeneration(
            title: title,
            genre: genre,
            theme: theme,
            targetReaders: targetReaders,
            totalChapters: totalChapters,
            background: background,
            style: style,
            specialRequirements: specialRequirements,
            onProgress: onProgress,
            onContent: onContent,
            onChapterComplete: onChapterComplete,
          );
        }
      }

      // 生成大纲
      onProgress?.call('正在生成大纲...');
      if (onContent != null) {
        onContent('\n开始生成大纲...\n');
      }
      
      final outline = await generateOutline(
        title: title,
        genre: genre,
        theme: theme,
        targetReaders: targetReaders,
        totalChapters: totalChapters,
        onProgress: onProgress,
        onContent: onContent,
      );
      
      _currentNovelOutline.value = outline;
      
      // 创建小说对象
      final novel = Novel(
        title: title,
        genre: genre,
        outline: outline,
        content: '',
        chapters: [],
        createdAt: DateTime.now(),
      );
      
      // 生成每一章
      for (var i = 1; i <= totalChapters; i++) {
        await _checkPause();
        if (_isPaused.value) {
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
          throw Exception('生成已暂停');
        }
        
        _currentGeneratingChapter.value = i;
        onProgress?.call('正在生成第$i章...');
        
        // 确保回调函数被调用
        if (onContent != null) {
          onContent('\n开始生成第$i章...\n');
        }
        
        final chapter = await generateChapter(
          title: title,
          number: i,
          outline: outline,
          previousChapters: novel.chapters,
          totalChapters: totalChapters,
          genre: genre,
          theme: theme,
          targetReaders: targetReaders,
          onProgress: onProgress,
          onContent: onContent,
        );
        
        novel.chapters.add(chapter);
        
        // 通知章节完成
        onChapterComplete?.call(i, chapter.title, chapter.content);
        
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
      _isGenerating.value = false;
      return novel;
    } catch (e) {
      _lastError.value = e.toString();
      print('生成小说失败: $e');
      rethrow;
    }
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
    final match = titleRegex.firstMatch(content ?? '');
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? '第$number章';
    }
    return '第$number章';
  }
} 