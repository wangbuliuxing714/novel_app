import 'package:get/get.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/prompts/system_prompts.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:novel_app/prompts/plot_prompts.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/services/content_review_service.dart';
import 'package:novel_app/screens/outline_preview_screen.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/outline_prompt_controller.dart';

class NovelGeneratorService extends GetxService {
  final AIService _aiService;
  final ApiConfigController _apiConfig;
  final CacheService _cacheService;
  final _outlineController = Get.find<OutlinePromptController>();
  final void Function(String)? onProgress;
  final String targetReaders = "青年读者";
  final RxList<String> _generatedParagraphs = <String>[].obs;

  NovelGeneratorService(
    this._aiService, 
    this._apiConfig, 
    this._cacheService,
    {this.onProgress}
  );

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
  }) async {
    try {
      _updateProgress("正在准备生成大纲...");
      
      // 每次生成的章节数
      const int batchSize = 10;  // 减小批次大小，提高成功率
      final StringBuffer fullOutline = StringBuffer();
      
      // 分批生成大纲
      for (int start = 1; start <= totalChapters; start += batchSize) {
        final int end = (start + batchSize - 1) > totalChapters ? totalChapters : (start + batchSize - 1);
        _updateProgress("正在生成第 $start 至 $end 章的大纲...\n如果生成时间较长，请耐心等待。");
        
        try {
          // 获取已生成的大纲内容作为上下文
          String existingOutline = fullOutline.toString();
          
          final batchOutline = await _generateOutlineContent(
            title,
            [genre],
            theme,
            totalChapters,
            start,
            end,
            existingOutline,
          );
          
          if (batchOutline.isEmpty) {
            throw Exception("生成的大纲内容为空，请重试");
          }
          
          fullOutline.write(batchOutline);
          _updateProgress("已完成 ${(end * 100 / totalChapters).toStringAsFixed(1)}% 的大纲生成");
          
          // 如果不是最后一批，等待一下再继续
          if (end < totalChapters) {
            await Future.delayed(const Duration(seconds: 3));
          }
        } catch (e) {
          _updateProgress("第 $start 至 $end 章的大纲生成失败：${e.toString()}\n正在重试...");
          // 当前批次失败，回退一个批次重试
          start -= batchSize;
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }
      }
      
      final outlineContent = fullOutline.toString();
      if (outlineContent.isEmpty) {
        throw Exception("生成的大纲内容为空，请重试");
      }
      
      // 显示全屏预览对话框
      _updateProgress("大纲生成完成，请检查并确认");
      final confirmedOutline = await Get.to(() => OutlinePreviewScreen(
        outline: outlineContent,
        onOutlineConfirmed: (String modifiedOutline) {
          Get.back(result: modifiedOutline);
        },
      ));
      
      return confirmedOutline ?? outlineContent;
    } catch (e) {
      _updateProgress("大纲生成失败：${e.toString()}\n请检查网络连接和API配置后重试");
      rethrow;
    }
  }

  Future<String> _generateOutlineContent(
    String title,
    List<String> genres,
    String theme,
    int totalChapters,
    int startChapter,
    int endChapter,
    String existingOutline,
  ) async {
    // 使用选中的提示词模板
    String template = _outlineController.currentTemplate;
    
    // 替换变量
    template = template
      .replaceAll('{title}', title)
      .replaceAll('{genre}', genres[0])
      .replaceAll('{theme}', theme)
      .replaceAll('{target_readers}', targetReaders)
      .replaceAll('{total_chapters}', totalChapters.toString());

    final genrePrompt = GenrePrompts.getPromptByGenre(genres[0]);
    final systemPrompt = '''【重要提示】
在开始生成内容之前：
1. 请仔细阅读并完全理解以下所有要求
2. 确保理解每一条规则的具体含义
3. 在生成内容时始终遵循这些规则
4. 如果对某条规则有疑问，请按最严格的标准执行

【核心原则】
你是一位专业的小说大纲策划师。请遵循以下原则：

1. 严格遵循已有大纲的风格和设定：
   - 必须与已生成的大纲保持一致性
   - 延续已有的情节发展方向
   - 保持人物性格和设定的统一
   - 注意前后章节的关联性
   - 合理设置伏笔和呼应

2. 章节规划（最高优先级）：
   - 每个章节都要有明确的主题
   - 情节要循序渐进
   - 设置适当的悬念
   - 注意前后呼应
   - 保持节奏的变化

3. 情节设计：
   - 每个章节都要有独特的看点
   - 避免情节重复
   - 保持合理的起伏
   - 设置适当的冲突
   - 注意细节的连贯性

4. 整体结构：
   - 注意与总体框架的呼应
   - 为后续发展预留空间
   - 保持故事节奏的变化
   - 设置恰当的转折点
   - 为高潮做好铺垫

类型参考：
${genrePrompt}

用户创作要求：
${theme}

请记住：你不能更改用户指定的任何角色名称和基本设定。''';

    final userPrompt = '''请为这部小说继续创作第$startChapter章到第$endChapter章的详细大纲。

已有的大纲内容：
${existingOutline.isEmpty ? '这是第一部分大纲' : existingOutline}

创作要求：
1. 必须与已有大纲保持连贯性和一致性
2. 每章都要有明确的主题和情节推进
3. 注意与前文的呼应和伏笔
4. 为后续章节预留发展空间
5. 符合${genres[0]}类型的特点

格式要求：
第N章：章节标题
- 情节概要：
- 重点场景：
- 关键人物：
- 重要伏笔：

请确保：
1. 完整输出第$startChapter章到第$endChapter章的大纲
2. 每章都有详细内容
3. 章节之间逻辑连贯
4. 符合用户要求和${genres[0]}类型特点''';

    final buffer = StringBuffer();
    onProgress?.call('正在生成大纲...');
    
    await for (final chunk in _aiService.generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 8000,
      temperature: 0.7,
    )) {
      buffer.write(chunk);
      onProgress?.call('正在生成大纲...\n\n${buffer.toString()}');
    }

    // 解析和格式化大纲
    final formattedOutline = _formatOutline(buffer.toString(), startChapter, endChapter);
    return formattedOutline;
  }

  String _formatOutline(String rawOutline, int startChapter, int endChapter) {
    final buffer = StringBuffer();
    final chapters = rawOutline.split(RegExp(r'第\d+章'));
    
    // 格式化每章大纲
    for (int i = 1; i <= chapters.length; i++) {
      if (i >= chapters.length) break;
      final chapter = chapters[i].trim();
      buffer.writeln('第${startChapter + i - 1}章：${_extractChapterTitle(chapter)}');
      buffer.writeln(_formatChapterOutline(chapter));
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  String _extractChapterTitle(String chapterContent) {
    final titleMatch = RegExp(r'[:：](.*?)\n').firstMatch(chapterContent);
    return titleMatch?.group(1)?.trim() ?? '未命名章节';
  }

  String _formatChapterOutline(String chapterContent) {
    final lines = chapterContent.split('\n');
    final buffer = StringBuffer();
    
    String currentSection = '';
    for (final line in lines) {
      if (line.contains('情节概要：')) currentSection = '情节概要';
      else if (line.contains('重点场景：')) currentSection = '重点场景';
      else if (line.contains('关键人物：')) currentSection = '关键人物';
      else if (line.contains('重要伏笔：')) currentSection = '重要伏笔';
      
      if (line.trim().isNotEmpty) {
        buffer.writeln(line.trim());
      }
    }
    
    return buffer.toString();
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
  }) async {
    // 生成章节缓存键
    final chapterKey = '${title}_$number';
    
    // 检查缓存
    final cachedContent = await _checkCache(chapterKey);
    if (cachedContent != null) {
      onProgress?.call('从缓存加载第$number章...');
      return Chapter(
        number: number,
        title: title,
        content: cachedContent,
      );
    }

    final context = _buildChapterContext(
      outline: outline,
      previousChapters: previousChapters,
      currentNumber: number,
      totalChapters: totalChapters,
    );

    // 获取成功的写作模式
    final successfulPatterns = _cacheService.getSuccessfulPatterns();
    
    // 根据章节进度动态调整生成参数
    final temperature = _getTemperatureForChapter(number, totalChapters);
    final maxTokens = _getMaxTokensForChapter(number);
    
    final genrePrompt = GenrePrompts.getPromptByGenre(genre);
    
    final systemPrompt = '''【重要提示】
在开始生成内容之前：
1. 请仔细阅读并完全理解以下所有要求
2. 确保理解每一条规则的具体含义
3. 在生成内容时始终遵循这些规则
4. 如果对某条规则有疑问，请按最严格的标准执行

【核心原则】
你是一位极具创造力的小说家。请遵循以下原则：

1. 严格遵循大纲（最高优先级）：
   - 必须完全按照大纲设定的情节发展来写作
   - 每个情节点都要与大纲保持一致
   - 禁止偏离大纲设定的主要情节走向
   - 确保所有关键剧情都按大纲展开
   - 细节可以发挥但不能违背大纲精神

2. 上下文连贯性（第二优先级）：
   - 必须仔细阅读前文内容，保持情节连贯
   - 人物性格、行为必须与前文一致
   - 所有新情节必须建立在已有内容基础上
   - 禁止出现与前文矛盾的描写
   - 新增内容必须考虑前文铺垫

3. 严格禁止重复：
   - 绝对禁止连续或相近段落出现相似内容
   - 每个段落必须包含全新信息
   - 禁止使用相似句式和词组
   - 实时检查并删除任何重复描写
   - 确保每个场景都有独特元素

4. 情节要求：
   - 故事情节必须围绕用户提供的具体要求展开
   - 每个章节都要有明确的情节推进
   - 前后章节要有合理的逻辑连接
   - 为每个章节设计独特的看点

5. 大纲格式：
   - 为每一章设计具体的标题
   - 详细描述每章的主要内容
   - 标注每章的重点情节和关键场景
   - 注明章节间的关联和伏笔

6. 整体结构：
   - 合理安排情节起伏
   - 设置适当的悬念和转折
   - 故事节奏要富有变化
   - 确保整体情节的完整性

类型参考：
${genrePrompt}

用户创作要求：
${theme}

请记住：你不能更改用户指定的任何角色名称和基本设定。''';

    final userPrompt = '''请根据以下信息创作第$number章的内容：

【重要提示】
- 必须严格遵循大纲中关于本章的所有设定
- 必须确保与前文的连贯性和一致性
- 禁止偏离大纲规划的情节发展方向
- 细节描写需要建立在已有内容基础上

【字数要求】
- 本章字数控制在3000-5000字之间
- 内容要充实完整
- 避免无意义的重复
- 段落结构要完整

【上下文信息】
$context

【创作指导】
${_designChapterFocus(number: number, totalChapters: totalChapters, outline: outline)}

特别要求：
1. 本章独特性（在严格遵循大纲的前提下）：
   - 采用${_getChapterStyle(number, totalChapters)}的写作风格
   - 重点描写${_getChapterFocus(number, totalChapters)}
   - 通过${_getChapterTechnique(number, totalChapters)}来推进剧情

2. 叙事创新：
   - 采用${_getNarrationStyle(number, totalChapters)}的叙事方式
   - 运用${_getDescriptionStyle(number, totalChapters)}的描写手法
   - 设置${_getPlotDevice(number, totalChapters)}类型的情节

3. 节奏控制：
   - 以${_getChapterRhythm(number, totalChapters)}的节奏展开
   - 在关键处${_getEmotionalStyle(number, totalChapters)}
   - 结尾要${_getEndingStyle(number, totalChapters)}

请确保本章在风格和内容上与其他章节有明显区别，给读者带来新鲜的阅读体验。''';

    final buffer = StringBuffer();
    onProgress?.call('正在生成第$number章...');
    
    await for (final chunk in _aiService.generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    )) {
      buffer.write(chunk);
      onProgress?.call('正在生成第$number章...\n\n${buffer.toString()}');
    }

    // 检查生成的内容是否有重复
    final paragraphs = buffer.toString().split('\n\n');
    final uniqueParagraphs = <String>[];
    
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;
      if (!_isParagraphDuplicate(paragraph)) {
        uniqueParagraphs.add(paragraph);
        _addGeneratedParagraph(paragraph);
      }
    }

    final content = uniqueParagraphs.join('\n\n');

    // 添加内容校对步骤
    onProgress?.call('正在校对和润色第$number章...');
    final contentReviewService = Get.find<ContentReviewService>();
    
    final reviewedContent = await contentReviewService.reviewContent(
      content: content,
      style: _determineStyle(number, totalChapters),
      model: AIModel.values.firstWhere(
        (m) => m.toString().split('.').last == _apiConfig.selectedModelId.value,
        orElse: () => AIModel.deepseek,
      ),
    );

    // 缓存成功生成的内容
    await _cacheContent(chapterKey, reviewedContent);

    onProgress?.call('第$number章校对完成');

    return Chapter(
      number: number,
      title: title,
      content: reviewedContent,
    );
  }

  double _getTemperatureForChapter(int number, int totalChapters) {
    final progress = number / totalChapters;
    // 在不同阶段使用不同的温度值，增加内容的多样性
    if (progress < 0.2) return 0.75; // 开始阶段，相对保守
    if (progress < 0.4) return 0.85; // 发展阶段，增加创造性
    if (progress < 0.7) return 0.9;  // 高潮阶段，最大创造性
    return 0.8; // 结尾阶段，适度平衡
  }

  int _getMaxTokensForChapter(int number) {
    // 根据章节重要性动态调整长度，但不超过5000字的token限制
    return 6000; // 约等于5000字
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

  String _buildChapterContext({
    required String outline,
    required List<Chapter> previousChapters,
    required int currentNumber,
    required int totalChapters,
  }) {
    final buffer = StringBuffer();
    
    // 添加大纲信息
    buffer.writeln('【总体大纲】');
    buffer.writeln(outline);
    buffer.writeln();

    // 添加前文概要
    if (previousChapters.isNotEmpty) {
      buffer.writeln('【前文概要】');
      for (int i = 0; i < previousChapters.length; i++) {
        final chapter = previousChapters[i];
        buffer.writeln('第${chapter.number}章 ${chapter.title}');
        buffer.writeln('概要：${_generateChapterSummary(chapter.content)}');
        buffer.writeln();
      }
    }

    // 添加最近两章的完整内容
    if (previousChapters.isNotEmpty) {
      buffer.writeln('【最近两章详细内容】');
      final recentChapters = previousChapters.length >= 2 
          ? previousChapters.sublist(previousChapters.length - 2)
          : previousChapters;
      
      for (final chapter in recentChapters) {
        buffer.writeln('第${chapter.number}章 ${chapter.title}');
        buffer.writeln(chapter.content);
        buffer.writeln();
      }
    }

    // 添加当前章节定位
    buffer.writeln('【当前章节定位】');
    final progress = currentNumber / totalChapters;
    if (currentNumber == 1) {
      buffer.writeln('开篇章节，需要：');
      buffer.writeln('- 介绍主要人物和背景');
      buffer.writeln('- 设置初始矛盾');
      buffer.writeln('- 埋下后续伏笔');
    } else if (progress < 0.3) {
      buffer.writeln('起始阶段，需要：');
      buffer.writeln('- 展开初期剧情');
      buffer.writeln('- 深化人物塑造');
      buffer.writeln('- 推进主要情节');
    } else if (progress < 0.7) {
      buffer.writeln('发展阶段，需要：');
      buffer.writeln('- 加强矛盾冲突');
      buffer.writeln('- 展示角色成长');
      buffer.writeln('- 推进核心剧情');
    } else if (progress < 0.9) {
      buffer.writeln('高潮阶段，需要：');
      buffer.writeln('- 制造情节高潮');
      buffer.writeln('- 解决主要矛盾');
      buffer.writeln('- 收束重要线索');
    } else {
      buffer.writeln('结局阶段，需要：');
      buffer.writeln('- 完美收官');
      buffer.writeln('- 点题升华');
      buffer.writeln('- 首尾呼应');
    }

    return buffer.toString();
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
      buffer.writeln('- 通过多线并行推进剧情');
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
  }) async {
    try {
      String outline;
      List<Chapter> chapters = [];
      String fullContent = '';

      if (continueGeneration) {
        // 从缓存中获取大纲和已生成的章节
        outline = await _checkCache('outline_$title') ?? '';
        if (outline.isEmpty) {
          throw Exception('未找到缓存的大纲，无法继续生成');
        }

        // 获取已缓存的章节
        for (int i = 1; i <= totalChapters; i++) {
          final cachedChapter = await _checkCache('chapter_${title}_$i');
          if (cachedChapter != null) {
            final chapter = Chapter(
              number: i,
              title: '第 $i 章',
              content: cachedChapter,
            );
            chapters.add(chapter);
            fullContent += cachedChapter + '\n\n';
          } else {
            // 从第一个未缓存的章节开始生成
            break;
          }
        }
      } else {
        // 清除之前的缓存
        _cacheService.clearAllCache();
        
        // 生成新大纲
        onProgress?.call('正在生成大纲...');
        outline = await generateOutline(
          title: title,
          genre: genre,
          theme: theme,
          targetReaders: targetReaders,
          totalChapters: totalChapters,
          onProgress: onProgress,
        );
        
        // 缓存大纲
        await _cacheService.cacheContent('outline_$title', outline);
      }

      // 继续生成剩余章节
      for (int i = chapters.length + 1; i <= totalChapters; i++) {
        onProgress?.call('正在生成第 $i 章...');
        final chapter = await generateChapter(
          title: '第 $i 章',
          number: i,
          outline: outline,
          previousChapters: chapters,
          totalChapters: totalChapters,
          genre: genre,
          theme: theme,
          onProgress: onProgress,
        );
        
        // 缓存新生成的章节
        await _cacheService.cacheContent('chapter_${title}_$i', chapter.content);
        
        chapters.add(chapter);
        fullContent += chapter.content + '\n\n';

        // 通知章节生成完成
        Get.find<NovelController>().addChapter(chapter);
      }

      return Novel(
        title: title,
        genre: genre,
        outline: outline,
        content: fullContent,
        chapters: chapters,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('生成小说失败: $e');
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
} 