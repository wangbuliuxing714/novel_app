import 'package:get/get.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/prompts/master_prompts.dart';
import 'package:novel_app/prompts/outline_generation.dart';
import 'package:novel_app/prompts/chapter_generation.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:novel_app/prompts/character_prompts.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/screens/outline_preview_screen.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/controllers/novel_controller.dart';

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

  NovelGeneratorService(
    this._aiService, 
    this._apiConfig, 
    this._cacheService,
    {this.onProgress}
  );

  // 获取当前生成状态的getter
  int get currentGeneratingChapter => _currentGeneratingChapter.value;
  bool get isGenerating => _isGenerating.value;
  String get lastError => _lastError.value;

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
      
      // 每次生成的章节数
      const int batchSize = 10;
      final StringBuffer fullOutline = StringBuffer();
      
      // 分批生成大纲
      for (int start = 1; start <= totalChapters; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, totalChapters);
        
        final systemPrompt = OutlineGeneration.getSystemPrompt(title, genre, theme);
        
        final outlinePrompt = OutlineGeneration.getOutlinePrompt(title, genre, theme, totalChapters);

        // 生成大纲
        String outlineContent = '';
        await for (final chunk in _aiService.generateTextStream(
          systemPrompt: systemPrompt,
          userPrompt: outlinePrompt,
          maxTokens: _getMaxTokensForChapter(0),
          temperature: 0.7,
        )) {
          outlineContent += chunk;
          if (onContent != null) {
            onContent(chunk);
          }
        }

        // 格式化大纲
        outlineContent = OutlineGeneration.formatOutline(outlineContent);

        fullOutline.write(outlineContent);
        fullOutline.write('\n\n');

        if (onProgress != null) {
          onProgress('已生成 ${end}/${totalChapters} 章大纲');
        }
      }

      return fullOutline.toString();
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
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      if (onProgress != null) {
        onProgress('正在生成第 $number 章...');
      }

      // 将之前的章节转换为字符串列表
      final previousChapterContents = previousChapters
          .map((chapter) => chapter.content)
          .toList();

      final chapterContent = await _generateChapterContent(
        title: title,
        chapterNumber: number,
        outline: outline,
        previousChapters: previousChapterContents,
        totalChapters: totalChapters,
        genre: genre,
        theme: theme,
        style: '轻松幽默',
        onProgress: onProgress,
        onContent: onContent,
      );

      final chapterKey = 'chapter_${title}_$number';
      
      // 检查缓存
      final cachedContent = await _checkCache(chapterKey);
      if (cachedContent != null) {
        return Chapter(
          number: number,
          title: title,
          content: cachedContent,
        );
      }

      // 缓存成功生成的内容
      await _cacheContent(chapterKey, chapterContent);

      // 创建新的章节对象
      return Chapter(
        number: number,
        title: title,
        content: chapterContent,
      );
    } catch (e) {
      print('生成章节失败: $e');
      rethrow;
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

  String _determineStyle(int currentChapter, int totalChapters) {
    final progress = currentChapter / totalChapters;
    
    if (progress < 0.3) {
      return '轻松爽快'; // 前期以轻松为主
    } else if (progress < 0.7) {
      return '热血激昂'; // 中期以热血为主
    } else {
      return '高潮迭起'; // 后期以高潮为主
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
    bool continueGeneration = false,
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      onProgress?.call('正在生成大纲...');
      
      // 第一步：生成整体架构
      onProgress?.call('正在设计故事整体架构...');
      final systemPrompt = OutlineGeneration.getSystemPrompt(title, genre, theme);
      final outlinePrompt = OutlineGeneration.getOutlinePrompt(title, genre, theme, totalChapters);

      String structureContent = '';
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: outlinePrompt,
        maxTokens: 2000,
        temperature: 0.7,
      )) {
        structureContent += chunk;
        if (onContent != null) {
          onContent(chunk);
        }
      }

      // 格式化架构内容
      structureContent = OutlineGeneration.formatOutline(structureContent);

      // 第二步：基于架构生成详细大纲
      onProgress?.call('正在细化故事情节...');
      
      // 分批生成大纲
      const int batchSize = 10;
      final StringBuffer fullOutline = StringBuffer();
      fullOutline.write(structureContent); // 先写入整体架构
      fullOutline.write('\n\n三、具体章节\n');
      
      for (int start = 1; start <= totalChapters; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, totalChapters);
        
        final detailPrompt = '''基于上述整体架构，请为第$start章到第$end章创作详细内容：
1. 每章必须包含：
   - 主要情节（2-3个关键点）
   - 次要情节（1-2个补充点）
   - 人物发展（重要人物的变化）
   - 伏笔/悬念（如果有）

2. 确保：
   - 每章情节符合整体架构设计
   - 前后章节的连贯性
   - 人物发展的合理性
   - 悬念和伏笔的布局

当前已有内容：
$structureContent''';

        String outlineContent = '';
        await for (final chunk in _aiService.generateTextStream(
          systemPrompt: systemPrompt,
          userPrompt: detailPrompt,
          maxTokens: 2000,
          temperature: 0.7,
        )) {
          outlineContent += chunk;
          if (onContent != null) {
            onContent(chunk);
          }
        }

        // 格式化大纲
        outlineContent = OutlineGeneration.formatOutline(outlineContent);

        fullOutline.write(outlineContent);
        fullOutline.write('\n\n');

        if (onProgress != null) {
          onProgress('已完成 ${end}/${totalChapters} 章节大纲');
        }
      }

      final outline = fullOutline.toString().trim();
      
      // 创建初始小说对象
      final novel = Novel(
        title: title,
        genre: genre,
        outline: outline,
        content: '',
        chapters: [],
        createdAt: DateTime.now(),
      );

      // 开始生成章节
      final List<Chapter> chapters = [];
      for (int i = 1; i <= totalChapters; i++) {
        onProgress?.call('正在生成第 $i 章...');
        
        final chapter = await generateChapter(
          title: title,
          number: i,
          outline: outline,
          previousChapters: chapters,
          totalChapters: totalChapters,
          genre: genre,
          theme: theme,
          onProgress: onProgress,
          onContent: onContent,
        );
        
        chapters.add(chapter);
      }

      // 更新小说对象，包含所有章节
      return Novel(
        title: title,
        genre: genre,
        outline: outline,
        content: chapters.map((c) => c.content).join('\n\n'),
        chapters: chapters,
        createdAt: DateTime.now(),
      );
    } catch (e) {
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
        
        currentPlan = {
          'title': line.trim(),
          'mainPlots': <String>[],
          'subPlots': <String>[],
          'characterDev': <String>[],
          'foreshadowing': <String>[],
        };
      } 
      // 解析章节内容
      else if (currentPlan != null) {
        final trimmedLine = line.trim();
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
    required Map<int, Map<String, dynamic>> chapterPlans,
  }) {
    final buffer = StringBuffer();
    
    // 添加当前章节的具体规划
    final currentPlan = chapterPlans[currentNumber];
    if (currentPlan != null) {
      buffer.writeln('【本章规划】');
      buffer.writeln('标题：${currentPlan['title']}');
      
      buffer.writeln('\n主要情节：');
      for (var plot in currentPlan['mainPlots']) {
        buffer.writeln('- $plot');
      }
      
      buffer.writeln('\n次要情节：');
      for (var plot in currentPlan['subPlots']) {
        buffer.writeln('- $plot');
      }
      
      buffer.writeln('\n人物发展：');
      for (var dev in currentPlan['characterDev']) {
        buffer.writeln('- $dev');
      }
      
      buffer.writeln('\n伏笔与悬念：');
      for (var hint in currentPlan['foreshadowing']) {
        buffer.writeln('- $hint');
      }
    }

    // 添加前文概要
    if (previousChapters.isNotEmpty) {
      buffer.writeln('\n【前文概要】');
      // 只获取最近的3章作为直接上下文
      final recentChapters = previousChapters.length > 3 
          ? previousChapters.sublist(previousChapters.length - 3)
          : previousChapters;
          
      for (var chapter in recentChapters) {
        buffer.writeln('第${chapter.number}章 概要：');
        buffer.writeln(_generateChapterSummary(chapter.content));
        buffer.writeln();
      }
    }

    // 添加后续章节规划概要
    if (currentNumber < totalChapters) {
      buffer.writeln('\n【后续章节规划】');
      for (var i = currentNumber + 1; i <= currentNumber + 2 && i <= totalChapters; i++) {
        final nextPlan = chapterPlans[i];
        if (nextPlan != null) {
          buffer.writeln('第$i章规划：');
          buffer.writeln('标题：${nextPlan['title']}');
          if (nextPlan['mainPlots'].isNotEmpty) {
            buffer.writeln('主要情节：${nextPlan['mainPlots'][0]}');
          }
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
    required int chapterNumber,
    required String outline,
    required List<String> previousChapters,
    required int totalChapters,
    required String genre,
    required String theme,
    required String style,
    void Function(String)? onProgress,
    void Function(String)? onContent,
  }) async {
    try {
      // 解析大纲获取具体章节规划
      final chapterPlans = await _parseOutline(outline);
      
      // 构建章节上下文
      final chapterContext = _buildChapterContext(
        outline: outline,
        previousChapters: previousChapters.map((content) => 
          Chapter(number: previousChapters.indexOf(content) + 1, 
                 title: '第${previousChapters.indexOf(content) + 1}章',
                 content: content)).toList(),
        currentNumber: chapterNumber,
        totalChapters: totalChapters,
        chapterPlans: chapterPlans,
      );

      final systemPrompt = ChapterGeneration.getSystemPrompt(style);
      
      final chapterPrompt = '''
${ChapterGeneration.getChapterPrompt(
        title: title,
        chapterNumber: chapterNumber,
        outline: outline,
        previousChapters: previousChapters,
        totalChapters: totalChapters,
        genre: genre,
        theme: theme,
        style: style,
      )}

详细的章节规划和上下文信息：
$chapterContext

创作要求：
1. 严格按照章节规划来创作本章内容
2. 确保与前文保持连贯性，并为后续章节做好铺垫
3. 直接写正文内容，不要包含任何大纲标记或标题
4. 字数要求：本章内容必须在3000-4000字之间，不能过短或过长


注意：请确保生成的内容长度在要求范围内，这一点很重要。''';

      final buffer = StringBuffer();
      String currentParagraph = '';
      
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: chapterPrompt,
        maxTokens: _getMaxTokensForChapter(chapterNumber),
        temperature: _getTemperatureForChapter(chapterNumber, totalChapters),
      )) {
        final cleanedChunk = ChapterGeneration.formatChapter(chunk);
        currentParagraph += cleanedChunk;
        
        // 当遇到段落结束标志时
        if (cleanedChunk.contains('\n\n')) {
          // 处理当前段落
          final processedParagraph = await _handleParagraphGeneration(
            currentParagraph,
            title: title,
            chapterNumber: chapterNumber,
            outline: outline,
            context: {
              'currentContext': buffer.toString(),
              'chapterTheme': theme,
              'style': style,
            },
          );
          
          buffer.write(processedParagraph);
          currentParagraph = '';
          
          if (onContent != null) {
            onContent(processedParagraph);
          }
        }
      }

      // 处理最后一个段落（如果有）
      if (currentParagraph.isNotEmpty) {
        final processedParagraph = await _handleParagraphGeneration(
          currentParagraph,
          title: title,
          chapterNumber: chapterNumber,
          outline: outline,
          context: {
            'currentContext': buffer.toString(),
            'chapterTheme': theme,
            'style': style,
          },
        );
        
        buffer.write(processedParagraph);
        if (onContent != null) {
          onContent(processedParagraph);
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
        return await _regenerateParagraph(
          title: title,
          chapterNumber: chapterNumber,
          outline: outline,
          context: context,
          avoidKeywords: checkResult.duplicateKeywords,
        );
      } else if (checkResult.similarity >= MEDIUM_SIMILARITY_THRESHOLD) {
        // 中等重复度：修改现有内容
        return await _modifyParagraph(
          paragraph,
          checkResult.duplicateKeywords,
          context: context,
        );
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

  // 保存生成进度
  Future<void> _saveGenerationProgress(String title, int chapter) async {
    await _cacheService.cacheContent('${title}_generation_progress', chapter.toString());
  }
  
  // 获取上次生成进度
  Future<int> _getLastGenerationProgress(String title) async {
    final progress = await _cacheService.getContent('${title}_generation_progress');
    return progress != null ? int.tryParse(progress) ?? 0 : 0;
  }

  // 添加一个方法来检查是否可以继续生成
  Future<bool> canContinueGeneration(String title) async {
    final progress = await _getLastGenerationProgress(title);
    final outline = await _checkCache('outline_$title');
    return progress > 0 && outline != null;
  }

  // 添加一个方法来获取生成进度信息
  Future<Map<String, dynamic>> getGenerationProgress(String title) async {
    final progress = await _getLastGenerationProgress(title);
    final outline = await _checkCache('outline_$title');
    return {
      'currentChapter': progress,
      'hasOutline': outline != null,
      'lastError': _lastError.value,
      'isGenerating': _isGenerating.value,
    };
  }

  // 添加一个方法来清除生成进度
  Future<void> clearGenerationProgress(String title) async {
    await _cacheService.removeContent('${title}_generation_progress');
    await _cacheService.removeContent('outline_$title');
    _currentGeneratingChapter.value = 0;
    _isGenerating.value = false;
    _lastError.value = '';
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
} 