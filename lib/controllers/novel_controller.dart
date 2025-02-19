import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/novel_outline.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/services/novel_generator_service.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/services/export_service.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class NovelController extends GetxController {
  final _novelGenerator = Get.find<NovelGeneratorService>();
  final _cacheService = Get.find<CacheService>();
  final _exportService = ExportService();
  final _characterTypeService = Get.find<CharacterTypeService>();
  final _characterCardService = Get.find<CharacterCardService>();
  final _aiService = Get.find<AIService>();
  
  final novels = <Novel>[].obs;
  final title = ''.obs;
  final background = ''.obs;
  final otherRequirements = ''.obs;
  final style = '轻松幽默'.obs;
  final totalChapters = 1.obs;
  final selectedGenres = <String>[].obs;
  
  // 新增角色选择相关的变量
  final selectedCharacterTypes = <CharacterType>[].obs;
  final selectedCharacterCards = <String, CharacterCard>{}.obs;
  
  final isGenerating = false.obs;
  final generationStatus = ''.obs;
  final generationProgress = 0.0.obs;
  final realtimeOutput = ''.obs;
  final isPaused = false.obs;
  final _shouldStop = false.obs;
  final _currentChapter = 0.obs;  // 添加当前章节记录
  final _hasOutline = false.obs;  // 添加大纲状态记录

  static const String _novelsBoxName = 'novels';
  static const String _chaptersBoxName = 'generated_chapters';
  late final Box<dynamic> _novelsBox;
  late final Box<dynamic> _chaptersBox;
  final RxList<Chapter> _generatedChapters = <Chapter>[].obs;

  List<Chapter> get generatedChapters => _generatedChapters;

  // 添加大纲相关变量
  final currentOutline = Rx<NovelOutline?>(null);
  final isUsingOutline = false.obs;

  @override
  void onInit() async {
    super.onInit();
    await _initHive();
    await loadNovels();  // 加载保存的小说
  }

  Future<void> _initHive() async {
    _novelsBox = await Hive.openBox(_novelsBoxName);
    _chaptersBox = await Hive.openBox(_chaptersBoxName);
    _loadGeneratedChapters();
  }

  Future<void> _saveToHive(Novel novel) async {
    try {
      final novelKey = 'novel_${novel.title}';
      await _novelsBox.put(novelKey, novel);
      print('保存小说成功: ${novel.title}');
    } catch (e) {
      print('保存到Hive失败: $e');
      rethrow;
    }
  }

  void _loadGeneratedChapters() {
    try {
      final savedChapters = _chaptersBox.get('chapters');
      if (savedChapters != null) {
        if (savedChapters is List) {
          _generatedChapters.value = savedChapters
              .map((chapterData) => chapterData is Chapter 
                  ? chapterData 
                  : Chapter.fromJson(Map<String, dynamic>.from(chapterData)))
              .toList();
        }
      }
    } catch (e) {
      print('加载章节失败: $e');
      _generatedChapters.clear();
    }
  }

  Future<void> saveChapter(String novelTitle, Chapter chapter) async {
    try {
      // 查找现有小说
      var novel = novels.firstWhere(
        (n) => n.title == novelTitle,
        orElse: () => Novel(
          title: novelTitle,
          genre: selectedGenres.join(','),
          outline: '',
          content: '',
          chapters: [],
          createdAt: DateTime.now(),
        ),
      );

      // 更新或添加章节
      var chapterIndex = novel.chapters.indexWhere((c) => c.number == chapter.number);
      if (chapterIndex != -1) {
        novel.chapters[chapterIndex] = chapter;
      } else {
        novel.chapters.add(chapter);
        // 按章节号排序
        novel.chapters.sort((a, b) => a.number.compareTo(b.number));
      }

      // 更新小说内容
      novel.content = novel.chapters.map((c) => c.content).join('\n\n');

      // 更新或添加小说到列表
      var novelIndex = novels.indexWhere((n) => n.title == novelTitle);
      if (novelIndex != -1) {
        novels[novelIndex] = novel;
      } else {
        novels.add(novel);
      }

      // 保存到本地存储
      await _saveToHive(novel);
      
      // 通知UI更新
      update();
      
    } catch (e) {
      print('保存章节失败: $e');
      rethrow;
    }
  }

  void updateTitle(String value) => title.value = value;
  void updateBackground(String value) => background.value = value;
  void updateOtherRequirements(String value) => otherRequirements.value = value;
  void updateStyle(String value) => style.value = value;
  void updateTotalChapters(int value) {
    // 确保章节数在合理范围内
    if (value > 0) {
      // 如果用户输入的值超过1000，给出提示但仍然允许设置
      if (value > 1000) {
        Get.snackbar(
          '提示', 
          '章节数量较多，生成时间可能会较长，建议不要超过1000章',
          duration: const Duration(seconds: 5),
        );
      }
      totalChapters.value = value;
    } else {
      Get.snackbar('错误', '章节数量必须大于0');
      totalChapters.value = 1;  // 设置为最小值
    }
  }

  void toggleGenre(String genre) {
    if (selectedGenres.contains(genre)) {
      selectedGenres.remove(genre);
    } else if (selectedGenres.length < 5) {
      selectedGenres.add(genre);
    }
  }

  void clearCache() {
    _cacheService.clearAllCache();
  }

  void _updateRealtimeOutput(String text) {
    realtimeOutput.value += text;
    if (realtimeOutput.value.length > 10000) {
      realtimeOutput.value = realtimeOutput.value.substring(
        realtimeOutput.value.length - 10000,
      );
    }
  }

  void _clearRealtimeOutput() {
    realtimeOutput.value = '';
  }

  // 添加新的角色选择相关方法
  void toggleCharacterType(CharacterType type) {
    if (selectedCharacterTypes.contains(type)) {
      selectedCharacterTypes.remove(type);
      // 移除该类型下已选择的角色卡片
      selectedCharacterCards.remove(type.id);
    } else {
      selectedCharacterTypes.add(type);
    }
  }

  void setCharacterCard(String typeId, CharacterCard card) {
    selectedCharacterCards[typeId] = card;
  }

  void removeCharacterCard(String typeId) {
    selectedCharacterCards.remove(typeId);
  }

  // 获取角色设定字符串
  String getCharacterSettings() {
    final buffer = StringBuffer();
    
    for (final type in selectedCharacterTypes) {
      final card = selectedCharacterCards[type.id];
      if (card != null) {
        buffer.writeln('${type.name}设定：');
        buffer.writeln('姓名：${card.name}');
        if (card.gender != null && card.gender!.isNotEmpty) {
          buffer.writeln('性别：${card.gender}');
        }
        if (card.age != null && card.age!.isNotEmpty) {
          buffer.writeln('年龄：${card.age}');
        }
        if (card.personalityTraits != null && card.personalityTraits!.isNotEmpty) {
          buffer.writeln('性格：${card.personalityTraits}');
        }
        if (card.background != null && card.background!.isNotEmpty) {
          buffer.writeln('背景：${card.background}');
        }
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }

  // 修改生成小说的方法
  Future<void> generateNovel({
    required String title,
    required String genre,
    required String theme,
    required int totalChapters,
    bool continueGeneration = false,
  }) async {
    if (title.isEmpty) {
      Get.snackbar('错误', '请输入小说标题');
      return;
    }

    if (selectedGenres.isEmpty) {
      Get.snackbar('错误', '请选择至少一个小说类型');
      return;
    }

    if (selectedCharacterTypes.isEmpty || selectedCharacterCards.isEmpty) {
      Get.snackbar('错误', '请选择至少一个角色');
      return;
    }

    if (isGenerating.value && !continueGeneration) return;
    
    isGenerating.value = true;
    generationStatus.value = '正在生成小说...';
    if (!continueGeneration) {
      realtimeOutput.value = '';
    }

    // 构建完整的创作要求
    final theme = '''${getCharacterSettings()}
故事背景：${background.value}
其他要求：${otherRequirements.value}''';

    try {
      // 创建或获取现有小说对象
      var novel = novels.firstWhere(
        (n) => n.title == title,
        orElse: () => Novel(
          title: title,
          genre: genre,
          outline: '',
          content: '',
          chapters: [],
          createdAt: DateTime.now(),
        ),
      );

      await _novelGenerator.generateNovel(
        title: title,
        genre: genre,
        theme: theme,
        targetReaders: '爱看网文的年轻人',
        totalChapters: totalChapters,
        continueGeneration: continueGeneration,
        onProgress: (status) async {
          generationStatus.value = status;
          _updateRealtimeOutput('\n$status\n');
          
          if (status.contains('正在生成大纲')) {
            generationProgress.value = 0.2;
            _hasOutline.value = true;
          } else if (status.contains('正在生成第')) {
            final currentChapter = int.tryParse(
                  status.split('第')[1].split('章')[0].trim(),
                ) ??
                0;
            _currentChapter.value = currentChapter;
            generationProgress.value =
                0.2 + 0.8 * (currentChapter / totalChapters);
          }
        },
        onContent: (content) {
          _updateRealtimeOutput(content);
        },
        onChapterComplete: (chapterNumber, chapterTitle, chapterContent) async {
          // 每章完成时立即保存
          final chapter = Chapter(
            number: chapterNumber,
            title: chapterTitle,
            content: chapterContent,
          );
          
          // 保存章节
          await saveChapter(title, chapter);
          
          // 更新进度提示
          Get.snackbar(
            '保存成功', 
            '第$chapterNumber章已保存到书库',
            duration: const Duration(seconds: 1),
          );
        },
      );

      // 只有在非暂停状态且当前章节等于总章节数时才显示完成
      if (!isPaused.value && _currentChapter.value >= totalChapters) {
        Get.snackbar('成功', '小说生成完成');
        // 生成完成后重置状态
        _resetGenerationState();
        // 清除生成进度
        await _novelGenerator.clearGenerationProgress();
      }
    } catch (e) {
      if (e.toString() == '生成已暂停') {
        // 暂停不是错误，不需要显示错误信息
        return;
      }
      _updateRealtimeOutput('\n生成失败：$e\n');
      Get.snackbar('错误', '生成失败：$e');
      // 发生错误时重置状态
      _resetGenerationState();
    } finally {
      if (!isPaused.value) {
        isGenerating.value = false;
      }
    }
  }

  // 修改重置生成状态的方法
  void _resetGenerationState() {
    isGenerating.value = false;
    isPaused.value = false;
    generationStatus.value = '';
  }

  void addChapter(Chapter chapter) {
    _generatedChapters.add(chapter);
    _sortChapters();
    saveChapter(title.value, chapter);
  }

  void deleteChapter(int chapterNumber) {
    _generatedChapters.removeWhere((chapter) => chapter.number == chapterNumber);
    if (novels.isNotEmpty) {
      var novel = novels.firstWhere(
        (n) => n.title == title.value,
        orElse: () => Novel(
          title: title.value,
          genre: selectedGenres.join(','),
          outline: '',
          content: '',
          chapters: [],
          createdAt: DateTime.now(),
        ),
      );
      
      novel.chapters.removeWhere((chapter) => chapter.number == chapterNumber);
      _saveToHive(novel);
    }
  }

  void clearAllChapters() {
    _generatedChapters.clear();
    if (novels.isNotEmpty) {
      var novel = novels.firstWhere(
        (n) => n.title == title.value,
        orElse: () => Novel(
          title: title.value,
          genre: selectedGenres.join(','),
          outline: '',
          content: '',
          chapters: [],
          createdAt: DateTime.now(),
        ),
      );
      
      novel.chapters.clear();
      novel.content = '';
      _saveToHive(novel);
    }
  }

  void updateChapter(Chapter chapter) {
    final index = _generatedChapters.indexWhere((c) => c.number == chapter.number);
    if (index != -1) {
      _generatedChapters[index] = chapter;
      saveChapter(title.value, chapter);
    }
  }

  Chapter? getChapter(int chapterNumber) {
    return _generatedChapters.firstWhereOrNull((chapter) => chapter.number == chapterNumber);
  }

  void _sortChapters() {
    _generatedChapters.sort((a, b) => a.number.compareTo(b.number));
  }

  Future<String> exportChapters(String selectedFormat, List<Chapter> selectedChapters) async {
    if (title.isEmpty) {
      return '请先生成小说';
    }

    try {
      final novel = novels.firstWhere((n) => n.title == title.value);
      final result = await _exportService.exportNovel(
        novel,
        selectedFormat,
        selectedChapters: selectedChapters,
      );
      return result;
    } catch (e) {
      return '导出失败：$e';
    }
  }

  // 导入大纲
  Future<bool> importOutline(String jsonString) async {
    final outline = NovelOutline.tryParse(jsonString);
    if (outline == null) {
      Get.snackbar('错误', '大纲格式不正确，请检查JSON格式');
      return false;
    }

    currentOutline.value = outline;
    isUsingOutline.value = true;
    title.value = outline.novelTitle;
    return true;
  }

  // 清除大纲
  void clearOutline() {
    currentOutline.value = null;
    isUsingOutline.value = false;
  }

  // 修改生成章节的方法，支持大纲
  Future<void> generateChapter(int chapterNumber) async {
    if (isGenerating.value) return;

    try {
      isGenerating.value = true;
      generationStatus.value = '正在生成第$chapterNumber章...';

      String prompt;
      if (isUsingOutline.value && currentOutline.value != null) {
        // 使用大纲生成
        final chapter = currentOutline.value!.chapters
            .firstWhere((ch) => ch.chapterNumber == chapterNumber);
        
        prompt = '''请根据以下大纲生成小说章节：
标题：${chapter.chapterTitle}
大纲内容：${chapter.contentOutline}

要求：
1. 严格按照大纲内容展开情节
2. 保持叙事连贯性
3. 细节要丰富生动
4. 符合小说整体风格

请直接返回生成的章节内容，不需要包含标题。''';
      } else {
        // 使用原有逻辑生成
        prompt = '生成第$chapterNumber章的内容...'; // 这里使用原有的提示词逻辑
      }

      // 调用AI服务生成内容
      final content = await _aiService.generateChapterContent(prompt);
      
      // 保存生成的章节
      final chapter = Chapter(
        number: chapterNumber,
        title: isUsingOutline.value 
            ? currentOutline.value!.chapters
                .firstWhere((ch) => ch.chapterNumber == chapterNumber)
                .chapterTitle
            : '第$chapterNumber章',
        content: content,
      );

      updateChapter(chapter);
      
      generationStatus.value = '第$chapterNumber章生成完成';
    } catch (e) {
      generationStatus.value = '生成失败：$e';
      rethrow;
    } finally {
      isGenerating.value = false;
    }
  }

  // 修改开始生成的方法
  void startGeneration() {
    if (isGenerating.value && !isPaused.value) return;
    
    // 重置所有状态
    _resetGenerationState();
    _currentChapter.value = 0;
    _hasOutline.value = false;
    generationProgress.value = 0;
    
    // 清除之前的输出
    _clearRealtimeOutput();
    clearAllChapters();
    
    // 开始生成
    generateNovel(
      title: title.value,
      genre: selectedGenres.join('、'),
      theme: getCharacterSettings(),
      totalChapters: totalChapters.value,
      continueGeneration: false,
    );
  }

  // 修改检查并继续生成的方法
  Future<void> checkAndContinueGeneration() async {
    if (!isPaused.value) return;
    
    try {
      // 重置暂停状态
      isPaused.value = false;
      _novelGenerator.resumeGeneration();
      
      // 从当前进度继续生成
      _updateRealtimeOutput('\n继续生成，从第${_currentChapter.value}章开始...\n');
      await generateNovel(
        title: title.value,
        genre: selectedGenres.join('、'),
        theme: getCharacterSettings(),
        totalChapters: totalChapters.value,
        continueGeneration: true,  // 设置为继续生成模式
      );
    } catch (e) {
      Get.snackbar('错误', '继续生成失败：$e');
      _resetGenerationState();
    }
  }

  // 修改暂停生成的方法
  void stopGeneration() {
    if (!isGenerating.value) return;
    isPaused.value = true;
    _novelGenerator.pauseGeneration();
    _updateRealtimeOutput('\n已暂停生成，当前进度：第${_currentChapter.value}章\n');
  }

  // 开始新小说
  void startNewNovel() {
    // 清除所有生成的章节和缓存
    _generatedChapters.clear();
    clearCache();
    
    // 重置所有状态为默认值
    title.value = '';
    background.value = '';
    otherRequirements.value = '';
    style.value = '轻松幽默';  // 设置默认风格
    totalChapters.value = 1;   // 设置为最小值
    selectedGenres.clear();
    selectedCharacterTypes.clear();
    selectedCharacterCards.clear();
    novels.clear();
    isGenerating.value = false;
    isPaused.value = false;
    
    // 重置进度和输出
    generationProgress.value = 0;
    generationStatus.value = '';
    realtimeOutput.value = '';
    
    // 通知用户
    Get.snackbar(
      '已清除',
      '所有内容已清除，请重新设置小说信息',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Get.theme.snackBarTheme.backgroundColor,
      colorText: Get.theme.snackBarTheme.actionTextColor,
    );
  }

  // 删除小说
  Future<void> deleteNovel(Novel novel) async {
    try {
      // 从列表中移除
      novels.remove(novel);
      
      // 从本地存储中删除
      final novelKey = 'novel_${novel.title}';
      await _novelsBox.delete(novelKey);
      
      // 如果是当前正在生成的小说，清除相关状态
      if (title.value == novel.title) {
        startNewNovel();
      }
      
      print('删除小说成功: ${novel.title}');
      Get.snackbar('成功', '已删除《${novel.title}》');
    } catch (e) {
      print('删除小说失败: $e');
      Get.snackbar('错误', '删除失败：$e');
    }
  }

  // 加载所有保存的小说
  Future<void> loadNovels() async {
    try {
      final keys = _novelsBox.keys.where((key) => key.toString().startsWith('novel_'));
      final loadedNovels = <Novel>[];
      
      for (final key in keys) {
        final novelData = _novelsBox.get(key);
        if (novelData != null) {
          try {
            if (novelData is Novel) {
              loadedNovels.add(novelData);
            } else if (novelData is Map) {
              final novel = Novel.fromJson(Map<String, dynamic>.from(novelData));
              loadedNovels.add(novel);
            }
          } catch (e) {
            print('解析小说数据失败: $e');
          }
        }
      }
      
      // 按创建时间排序，最新的在前面
      loadedNovels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      novels.value = loadedNovels;
      print('加载到 ${loadedNovels.length} 本小说');
    } catch (e) {
      print('加载小说失败: $e');
    }
  }

  Future<String> continueNovel({
    required Novel novel,
    required Chapter chapter,
    required String prompt,
    required int chapterCount,
  }) async {
    try {
      final systemPrompt = '''你是一位专业的小说大纲续写助手。请根据以下信息续写小说大纲：

小说标题：${novel.title}
小说类型：${novel.genre}
当前大纲：${novel.outline}

续写要求：
1. 保持故事情节的连贯性和合理性
2. 延续原有的写作风格和人物性格
3. 生成${chapterCount}个新章节的大纲
4. 每个章节包含标题和大纲内容
5. 遵循用户的续写提示

用户续写提示：$prompt

请直接输出续写的大纲内容，格式如下：
第X章：章节标题
章节大纲内容

第X+1章：章节标题
章节大纲内容
...
''';

      final response = await _aiService.generateChapterContent(systemPrompt);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> generateChapterFromOutline({
    required Novel novel,
    required int chapterNumber,
    required String chapterTitle,
    required String chapterOutline,
  }) async {
    try {
      final systemPrompt = '''你是一位专业的小说创作助手。请根据以下信息生成小说章节内容：

小说标题：${novel.title}
小说类型：${novel.genre}
小说大纲：${novel.outline}

当前章节信息：
章节号：第${chapterNumber}章
章节标题：${chapterTitle}
章节大纲：${chapterOutline}

要求：
1. 严格按照大纲内容展开情节
2. 保持叙事连贯性和合理性
3. 细节要丰富生动
4. 符合小说整体风格
5. 字数在3000-5000字之间

请直接返回生成的章节内容，不需要包含标题。''';

      final response = await _aiService.generateChapterContent(systemPrompt);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveGeneratedChapters(String content) async {
    final chapterPattern = RegExp(r'第(\d+)章：(.*?)\n(.*?)(?=第\d+章|$)', dotAll: true);
    final matches = chapterPattern.allMatches(content);
    
    for (final match in matches) {
      final number = int.parse(match.group(1)!);
      final title = match.group(2)!.trim();
      final content = match.group(3)!.trim();
      
      final chapter = Chapter(
        number: number,
        title: title,
        content: content,
      );
      
      addChapter(chapter);
    }
  }
}