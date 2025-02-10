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

class NovelGeneratorService extends GetxService {
  final AIService _aiService;
  final ApiConfigController _apiConfig;
  final CacheService _cacheService;
  final void Function(String)? onProgress;
  final String targetReaders = "青年读者";
  final RxList<String> _generatedParagraphs = <String>[].obs;
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
    _generatedParagraphs.add(paragraph);
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

  int _getMaxTokensForChapter(int number) {
    // 增加 token 限制到 8000，约等于 6000-7000 字
    return 8000;
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
    final cleanedLines = lines.where((line) {
      final trimmedLine = line.trim();
      // 过滤掉空行
      if (trimmedLine.isEmpty) return false;
      
      // 过滤掉以标记开头的行
      for (final marker in markersToRemove) {
        if (trimmedLine.startsWith(marker) || 
            trimmedLine.startsWith('- $marker') ||
            trimmedLine == '-') {
          return false;
        }
      }
      
      // 过滤掉纯数字编号的行
      if (RegExp(r'^\d+\.$').hasMatch(trimmedLine)) {
        return false;
      }
      
      return true;
    }).toList();

    // 合并处理后的内容
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

请严格按照章节规划来创作本章内容，确保与前文保持连贯性，并为后续章节做好铺垫。
注意：直接写正文内容，不要包含任何大纲标记或标题。''';

      final buffer = StringBuffer();
      
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: chapterPrompt,
        maxTokens: _getMaxTokensForChapter(chapterNumber),
        temperature: _getTemperatureForChapter(chapterNumber, totalChapters),
      )) {
        final cleanedChunk = ChapterGeneration.formatChapter(chunk);
        buffer.write(cleanedChunk);
        if (onContent != null) {
          onContent(cleanedChunk);
        }
      }

      // 清理生成的内容
      final content = _cleanGeneratedContent(buffer.toString());
      
      return content;
    } catch (e) {
      print('生成章节失败: $e');
      rethrow;
    }
  }

  Future<String> _generateWithAI(String prompt) async {
    try {
      String response = '';
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: '''作为一个专业的小说创作助手，请遵循以下创作原则：

1. 故事逻辑：
   - 确保因果关系清晰合理，事件发展有其必然性
   - 人物行为要符合其性格特征和处境
   - 情节转折要有铺垫，避免突兀
   - 矛盾冲突的解决要符合逻辑
   - 故事背景要前后一致，细节要互相呼应

2. 叙事结构：
   - 采用灵活多变的叙事手法，避免单一直线式发展
   - 合理安排伏笔和悬念，让故事更有层次感
   - 注意时间线的合理性，避免前后矛盾
   - 场景转换要流畅自然，不生硬突兀
   - 故事节奏要有张弛，紧凑处突出戏剧性

3. 人物塑造：
   - 赋予角色丰富的心理活动和独特性格
   - 人物成长要符合其经历和环境
   - 人物关系要复杂立体，互动要自然
   - 对话要体现人物性格和身份特点
   - 避免脸谱化和类型化的人物描写

4. 环境描写：
   - 场景描写要与情节和人物情感相呼应
   - 细节要生动传神，突出关键特征
   - 环境氛围要配合故事发展
   - 感官描写要丰富多样
   - 避免无关的环境描写，保持紧凑

5. 语言表达：
   - 用词准确生动，避免重复和陈词滥调
   - 句式灵活多样，富有韵律感
   - 善用修辞手法，但不过分堆砌
   - 对话要自然流畅，符合说话人特点
   - 描写要细腻传神，避免空洞

请基于以上要求，创作出逻辑严密、情节生动、人物丰满的精彩内容。''',
        userPrompt: prompt,
      )) {
        response += chunk;
      }
      return response;
    } catch (e) {
      return '生成失败: $e';
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
} 