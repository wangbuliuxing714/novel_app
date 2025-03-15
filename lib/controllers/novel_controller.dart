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
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/services/conversation_manager.dart';

class NovelController extends GetxController {
  final _novelGenerator = Get.find<NovelGeneratorService>();
  final _cacheService = Get.find<CacheService>();
  final _exportService = ExportService();
  final _characterTypeService = Get.find<CharacterTypeService>();
  final _characterCardService = Get.find<CharacterCardService>();
  final _aiService = Get.find<AIService>();
  final _promptPackageController = Get.find<PromptPackageController>();
  
  final novels = <Novel>[].obs;
  final title = ''.obs;
  final background = ''.obs;
  final otherRequirements = ''.obs;
  final style = '轻松幽默'.obs;
  final selectedGenres = <String>[].obs;
  
  // 添加目标读者变量
  final targetReader = '男性向'.obs;
  
  // 新增角色选择相关的变量
  final selectedCharacterTypes = <CharacterType>[].obs;
  final Map<String, CharacterCard> selectedCharacterCards = <String, CharacterCard>{}.obs;
  
  // 短篇小说相关变量
  final isShortNovel = false.obs;
  final shortNovelWordCount = 15000.obs; // 默认1.5万字
  
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

  // 新增属性
  final RxString _currentNovelBackground = ''.obs;
  final RxList<String> _specialRequirements = <String>[].obs;
  final RxString _selectedStyle = ''.obs;
  final RxInt _totalChapters = 5.obs;
  final RxString _currentNovelTitle = ''.obs;
  
  // 新增getter
  String get currentNovelBackground => _currentNovelBackground.value;
  List<String> get specialRequirements => _specialRequirements;
  String get selectedStyle => _selectedStyle.value;
  int get totalChapters => _totalChapters.value;
  RxInt get totalChaptersRx => _totalChapters;
  String get currentNovelTitle => _currentNovelTitle.value;
  
  // 新增setter方法
  void setNovelTitle(String title) {
    _currentNovelTitle.value = title;
  }
  
  void setNovelBackground(String background) {
    _currentNovelBackground.value = background;
  }
  
  void setSpecialRequirements(List<String> requirements) {
    _specialRequirements.assignAll(requirements);
  }
  
  void setSelectedGenres(List<String> genres) {
    selectedGenres.assignAll(genres);
  }
  
  void setSelectedCharacterTypes(List<CharacterType> types) {
    selectedCharacterTypes.assignAll(types);
  }
  
  void setSelectedCharacterCards(Map<String, CharacterCard> cards) {
    selectedCharacterCards.assignAll(cards);
  }
  
  void setSelectedStyle(String style) {
    _selectedStyle.value = style;
  }
  
  void setTargetReader(String value) => targetReader.value = value;
  
  void setTotalChapters(int value) {
    if (value > 0) {
      // 如果用户输入的值超过1000，给出提示但仍然允许设置
      if (value > 1000) {
        Get.snackbar(
          '提示', 
          '章节数量较多，生成时间可能会较长，建议不要超过1000章',
          duration: const Duration(seconds: 5),
        );
      }
      _totalChapters.value = value;
    } else {
      Get.snackbar('错误', '章节数量必须大于0');
      _totalChapters.value = 1;  // 设置为最小值
    }
  }
  
  void setUsingOutline(bool useOutline) {
    isUsingOutline.value = useOutline;
  }

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
  void updateTargetReader(String value) => targetReader.value = value;
  void updateTotalChapters(int value) {
    if (value > 0) {
      // 如果用户输入的值超过1000，给出提示但仍然允许设置
      if (value > 1000) {
        Get.snackbar(
          '提示', 
          '章节数量较多，生成时间可能会较长，建议不要超过1000章',
          duration: const Duration(seconds: 5),
        );
      }
      _totalChapters.value = value;
    } else {
      Get.snackbar('错误', '章节数量必须大于0');
      _totalChapters.value = 1;  // 设置为最小值
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
    print('清除所有缓存');
    _cacheService.clearAllCache();
    _novelGenerator.clearFailedGenerationCache();
    
    // 清除生成进度
    _novelGenerator.clearGenerationProgress();
  }

  void _updateRealtimeOutput(String text) {
    if (text.isEmpty) return;
    
    // 添加日志，帮助调试
    print('更新实时输出: ${text.length} 字符');
    
    // 确保在主线程更新UI
    Get.engine.addPostFrameCallback((_) {
      realtimeOutput.value += text;
      if (realtimeOutput.value.length > 10000) {
        realtimeOutput.value = realtimeOutput.value.substring(
          realtimeOutput.value.length - 10000,
        );
      }
    });
  }

  void _clearRealtimeOutput() {
    print('清除实时输出');
    realtimeOutput.value = '';
  }

  // 添加新的角色选择相关方法
  void toggleCharacterType(CharacterType type) {
    if (selectedCharacterTypes.contains(type)) {
      selectedCharacterTypes.remove(type);
      // 移除该类型下已选择的角色卡片
      selectedCharacterCards.remove(type);
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

  // 导入大纲
  Future<bool> importOutline(String outlineText) async {
    try {
      print('开始解析大纲文本...');
      
      // 解析大纲文本
      final lines = outlineText.split('\n');
      String novelTitle = '';
      final chapters = <Map<String, dynamic>>[];
      int currentChapter = 0;
      StringBuffer currentContent = StringBuffer();
      
      // 第一步：尝试提取小说标题
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        // 检查是否是小说标题（通常在开头，可能被《》或""包围）
        if ((line.startsWith('《') && line.endsWith('》')) || 
            (line.startsWith('"') && line.endsWith('"')) ||
            (line.startsWith('标题：') || line.startsWith('小说标题：'))) {
          
          // 提取标题，去除可能的包围符号
          if (line.startsWith('《') && line.endsWith('》')) {
            novelTitle = line.substring(1, line.length - 1);
          } else if (line.startsWith('"') && line.endsWith('"')) {
            novelTitle = line.substring(1, line.length - 1);
          } else if (line.startsWith('标题：')) {
            novelTitle = line.substring(3).trim();
          } else if (line.startsWith('小说标题：')) {
            novelTitle = line.substring(5).trim();
          } else {
            novelTitle = line;
          }
          
          print('提取到小说标题: $novelTitle');
          break;
        }
      }
      
      // 如果没有找到明确的标题，使用第一行非空文本作为标题
      if (novelTitle.isEmpty) {
        for (String line in lines) {
          line = line.trim();
          if (line.isNotEmpty && !line.startsWith('第') && line.length < 30) {
            novelTitle = line;
            print('使用第一行文本作为标题: $novelTitle');
            break;
          }
        }
      }
      
      // 如果仍然没有标题，使用默认标题
      if (novelTitle.isEmpty) {
        novelTitle = title.value.isNotEmpty ? title.value : '新小说';
        print('使用默认标题: $novelTitle');
      }
      
      // 第二步：解析章节
      // 尝试多种章节标记模式
      final chapterPatterns = [
        RegExp(r'^第(\d+)章[：:](.*?)$'),  // 标准格式：第X章：标题
        RegExp(r'^第(\d+)章\s+(.*?)$'),    // 空格分隔：第X章 标题
        RegExp(r'^(\d+)[\.、](.*?)$'),     // 数字编号：1.标题 或 1、标题
        RegExp(r'^Chapter\s*(\d+)[：:.\s]+(.*?)$', caseSensitive: false),  // 英文格式
      ];
      
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        bool isChapterTitle = false;
        RegExpMatch? match;
        
        // 尝试所有章节标题模式
        for (final pattern in chapterPatterns) {
          match = pattern.firstMatch(line);
          if (match != null) {
            isChapterTitle = true;
            break;
          }
        }
        
        if (isChapterTitle && match != null) {
          // 如果有上一章的内容，保存它
          if (currentChapter > 0 && currentContent.isNotEmpty) {
            final lastChapterIndex = chapters.indexWhere((ch) => ch['chapterNumber'] == currentChapter);
            if (lastChapterIndex != -1) {
              chapters[lastChapterIndex]['contentOutline'] = currentContent.toString().trim();
            }
            currentContent.clear();
          }
          
          currentChapter = int.parse(match.group(1)!);
          final chapterTitle = match.group(2)?.trim() ?? '';
          
          chapters.add({
            'chapterNumber': currentChapter,
            'chapterTitle': chapterTitle.isEmpty ? '第$currentChapter章' : chapterTitle,
            'contentOutline': ''
          });
          
          print('提取到章节: 第$currentChapter章 - ${chapterTitle.isEmpty ? "无标题" : chapterTitle}');
        } else if (currentChapter > 0) {
          // 其他行都视为当前章节的大纲内容
          currentContent.writeln(line);
        }
      }
      
      // 保存最后一章的内容
      if (currentChapter > 0 && currentContent.isNotEmpty) {
        final lastChapterIndex = chapters.indexWhere((ch) => ch['chapterNumber'] == currentChapter);
        if (lastChapterIndex != -1) {
          chapters[lastChapterIndex]['contentOutline'] = currentContent.toString().trim();
        }
      }
      
      // 如果没有识别到任何章节，尝试自动分章
      if (chapters.isEmpty) {
        print('未识别到章节标记，尝试自动分章...');
        
        // 按段落分割文本
        final paragraphs = outlineText.split(RegExp(r'\n\s*\n'));
        final nonEmptyParagraphs = paragraphs.where((p) => p.trim().isNotEmpty).toList();
        
        // 确定章节数量（至少3章，最多5章或段落数）
        final chapterCount = nonEmptyParagraphs.length < 3 ? 3 : 
                            (nonEmptyParagraphs.length > 5 ? 5 : nonEmptyParagraphs.length);
        
        // 计算每章应包含的段落数
        final paragraphsPerChapter = (nonEmptyParagraphs.length / chapterCount).ceil();
        
        for (int i = 0; i < chapterCount; i++) {
          final chapterNumber = i + 1;
          final startIndex = i * paragraphsPerChapter;
          final endIndex = (startIndex + paragraphsPerChapter <= nonEmptyParagraphs.length) 
              ? startIndex + paragraphsPerChapter 
              : nonEmptyParagraphs.length;
          
          // 提取该章节的段落
          final chapterParagraphs = nonEmptyParagraphs.sublist(
              startIndex, 
              endIndex > nonEmptyParagraphs.length ? nonEmptyParagraphs.length : endIndex
          );
          
          // 使用第一段的前20个字符作为章节标题
          String chapterTitle = '';
          if (chapterParagraphs.isNotEmpty) {
            final firstPara = chapterParagraphs[0].trim();
            chapterTitle = firstPara.length > 20 ? firstPara.substring(0, 20) + '...' : firstPara;
          }
          
          // 如果标题为空，使用默认标题
          if (chapterTitle.isEmpty) {
            chapterTitle = '第$chapterNumber章';
          }
          
          // 将剩余段落作为章节内容
          final contentBuffer = StringBuffer();
          for (int j = 0; j < chapterParagraphs.length; j++) {
            contentBuffer.writeln(chapterParagraphs[j].trim());
          }
          
          chapters.add({
            'chapterNumber': chapterNumber,
            'chapterTitle': chapterTitle,
            'contentOutline': contentBuffer.toString().trim()
          });
          
          print('自动创建章节: 第$chapterNumber章 - $chapterTitle');
        }
      }
      
      // 确保章节按顺序排序
      chapters.sort((a, b) => a['chapterNumber'].compareTo(b['chapterNumber']));
      
      // 创建大纲对象
      final outline = NovelOutline(
        novelTitle: novelTitle,
        chapters: chapters.map((ch) => ChapterOutline(
          chapterNumber: ch['chapterNumber'],
          chapterTitle: ch['chapterTitle'],
          contentOutline: ch['contentOutline'],
        )).toList(),
      );
      
      // 更新应用状态
      currentOutline.value = outline;
      isUsingOutline.value = true;
      title.value = outline.novelTitle;
      _totalChapters.value = outline.chapters.length;
      
      print('导入大纲成功：${outline.chapters.length} 章');
      for (var ch in outline.chapters) {
        print('第${ch.chapterNumber}章：${ch.chapterTitle}\n${ch.contentOutline.substring(0, ch.contentOutline.length > 50 ? 50 : ch.contentOutline.length)}...\n');
      }
      
      return true;
    } catch (e) {
      print('导入大纲失败：$e');
      Get.snackbar('错误', '大纲解析失败：$e', 
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM
      );
      return false;
    }
  }

  // 增加generateNovel方法用于生成小说
  Future<void> generateNovel({
    bool continueGeneration = false,
    bool isShortNovel = false,
    int wordCount = 15000,
  }) async {
    if (isGenerating.value && !continueGeneration) {
      Get.snackbar('提示', '正在生成中，请稍候');
      return;
    }
    
    try {
      // 设置生成状态
      isGenerating.value = true;
      generationProgress.value = 0.0;
      
      if (!continueGeneration) {
        _clearRealtimeOutput(); // 如果是新生成，清除之前的输出
        generationStatus.value = '准备生成';
      }

      // 获取角色设定
      final characterSettings = getCharacterSettings();
      
      // 更新状态
      generationStatus.value = '正在生成';
      
      // 调用生成服务
      final novel = await _novelGenerator.generateNovel(
        title: title.value,
        genres: selectedGenres,
        background: background.value,
        otherRequirements: otherRequirements.value,
        style: style.value,
        targetReader: targetReader.value,
        totalChapters: _totalChapters.value,
        continueGeneration: continueGeneration,
        useOutline: isUsingOutline.value,
        outline: currentOutline.value,
        isShortNovel: isShortNovel,
        wordCount: wordCount,
        characterCards: selectedCharacterCards,
        characterTypes: selectedCharacterTypes,
        updateRealtimeOutput: _updateRealtimeOutput,
        updateGenerationStatus: (status) => generationStatus.value = status,
        updateGenerationProgress: (progress) => generationProgress.value = progress,
        onNovelCreated: (createdNovel) async {
          // 保存生成的小说
          final index = novels.indexWhere((n) => n.title == createdNovel.title);
          if (index != -1) {
            novels[index] = createdNovel;
          } else {
            novels.add(createdNovel);
          }
          
          // 保存到本地存储
          await _saveToHive(createdNovel);
        }
      );
      
      // 更新生成状态
      isGenerating.value = false;
      generationProgress.value = 1.0;
      generationStatus.value = '生成完成';
      
      // 显示完成提示
      Get.snackbar(
        '完成', 
        isShortNovel ? '短篇小说生成完成' : '小说生成完成',
        duration: const Duration(seconds: 3),
      );
      
    } catch (e) {
      print('生成失败: $e');
      
      if ('$e'.contains('暂停')) {
        // 如果是用户主动暂停，设置暂停状态
        isPaused.value = true;
        generationStatus.value = '已暂停';
        Get.snackbar('已暂停', '生成已暂停，您可以稍后继续');
      } else {
        // 其他错误
        isGenerating.value = false;
        generationStatus.value = '生成失败: $e';
        Get.snackbar('错误', '生成失败: $e');
      }
    }
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

  // 清除大纲
  void clearOutline() {
    currentOutline.value = null;
    isUsingOutline.value = false;
  }

  // 开始生成小说
  Future<void> startGeneration() async {
    if (isGenerating.value) return;
    
    // 清除实时输出
    _clearRealtimeOutput();
    
    // 如果不是使用大纲模式，则清除所有章节
    if (!isUsingOutline.value) {
      clearAllChapters();
    }
    
    // 开始生成
    generateNovel(
      isShortNovel: isShortNovel.value,
      wordCount: shortNovelWordCount.value,
    );
  }

  // 修改检查并继续生成的方法
  Future<void> checkAndContinueGeneration() async {
    if (!isPaused.value) return;
    
    try {
      // 重置暂停状态
      isPaused.value = false;
      
      // 通知生成服务继续生成
      _novelGenerator.resumeGeneration();
      
      // 从当前进度继续生成
      _updateRealtimeOutput('\n继续生成，从第${_currentChapter.value}章开始...\n');
      
      // 通知用户
      Get.snackbar(
        '继续生成', 
        '正在从第${_currentChapter.value}章继续生成',
        duration: const Duration(seconds: 2),
      );
      
      // 继续生成过程
      await generateNovel(
        continueGeneration: true,  // 设置为继续生成模式
        isShortNovel: isShortNovel.value,
        wordCount: shortNovelWordCount.value,
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
    
    // 保存当前状态，确保暂停状态被正确保存
    Get.snackbar(
      '已暂停', 
      '生成已暂停，可以点击"继续生成"按钮恢复',
      duration: const Duration(seconds: 2),
    );
  }

  // 添加开始新小说的方法
  void startNewNovel() {
    // 清除所有状态
    print('开始新小说，清除所有状态');
    
    // 清除输入状态
    title.value = '';
    background.value = '';
    otherRequirements.value = '';
    selectedGenres.clear();
    selectedCharacterTypes.clear();
    selectedCharacterCards.clear();
    
    // 清除生成状态
    _clearRealtimeOutput();
    generationStatus.value = '';
    generationProgress.value = 0.0;
    _currentChapter.value = 0;
    _hasOutline.value = false;
    
    // 清除大纲状态
    currentOutline.value = null;
    isUsingOutline.value = false;
    
    // 清除缓存
    clearCache();
    
    // 清除生成的章节
    _generatedChapters.clear();
    
    // 通知用户
    Get.snackbar(
      '已重置', 
      '所有状态已清除，可以开始创作新小说',
      duration: const Duration(seconds: 2),
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

  // 续写小说
  Future<String> continueNovel({
    required Novel novel,
    required Chapter chapter,
    required String prompt,
    required int chapterCount,
  }) async {
    try {
      final systemPrompt = '''你是一位专业的小说创作助手。请根据以下信息生成小说续写大纲：

小说标题：${novel.title}
小说类型：${novel.genre}
当前大纲：
${chapter.content}

续写提示：
${prompt}

请生成${chapterCount}个新章节的详细大纲，每个章节包含章节号、标题和具体内容描述。
按照以下格式输出：

第N章：章节标题
章节大纲内容

第N+1章：章节标题
章节大纲内容
...
''';

      // 使用大纲模型生成内容
      final response = await _aiService.generateOutline(systemPrompt, novelTitle: novel.title);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> generateOutlineFromTitle({
    required String title,
    required String genre,
    required String theme,
    required String targetReaders,
    required int totalChapters,
  }) async {
    try {
      final systemPrompt = '''你是一位专业的小说策划助手。请基于以下信息生成小说大纲：

小说标题：$title
小说类型：$genre
小说主题：$theme
目标读者：$targetReaders
计划章节数：$totalChapters

请生成大纲，包括以下部分：
1. 整体架构与世界观
2. 主要角色与背景
3. 核心情节发展线
4. 每章节概要（共$totalChapters章）

输出格式：

一、整体架构与世界观
[详细描述]

二、主要角色与背景
[详细描述]

三、核心情节发展线
[详细描述]

四、章节大纲
第1章：章节标题
章节大纲内容

第2章：章节标题
章节大纲内容
...
''';

      final response = await _aiService.generateChapterContent(systemPrompt, novelTitle: title, chapterNumber: 0);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // 从大纲中生成章节内容
  Future<Chapter> generateChapterFromOutline({
    required int chapterNumber,
    String? outlineString,
    Function(String)? onStatus,
  }) async {
    try {
      if (currentOutline.value == null) {
        throw Exception('没有可用的大纲');
      }
      
      final novelTitle = currentOutline.value!.novelTitle;
      final chapterOutline = currentOutline.value!.chapters.firstWhere(
        (ch) => ch.chapterNumber == chapterNumber,
        orElse: () => throw Exception('找不到章节大纲'),
      );
      
      // 获取已生成的章节
      final previousChapters = _generatedChapters
        .where((ch) => ch.number < chapterNumber)
        .toList();
      
      // 使用传入的大纲字符串，如果没有则从大纲对象构建
      final finalOutlineString = outlineString ?? currentOutline.value!.toJson()['chapters']
        .map((ch) => '第${ch['chapterNumber']}章：${ch['chapterTitle']}\n${ch['contentOutline']}')
        .join('\n\n');
      
      onStatus?.call('正在生成第$chapterNumber章...');
      
      // 生成章节内容，传递小说标题
      final chapter = await _novelGenerator.generateChapter(
        title: novelTitle,
        outline: finalOutlineString,
        number: chapterNumber,
        totalChapters: currentOutline.value!.chapters.length,
        previousChapters: previousChapters,
        onProgress: onStatus,
        onContent: (content) => _updateRealtimeOutput(content),
      );
      
      // 保存到已生成章节列表
      final existingIndex = _generatedChapters.indexWhere((ch) => ch.number == chapterNumber);
      if (existingIndex >= 0) {
        _generatedChapters[existingIndex] = chapter;
      } else {
        _generatedChapters.add(chapter);
        // 确保章节按顺序排序
        _generatedChapters.sort((a, b) => a.number.compareTo(b.number));
      }
      
      // 保存到Hive
      await _saveChapterToHive(novelTitle, chapter);
      
      onStatus?.call('第$chapterNumber章生成完成');
      return chapter;
    } catch (e) {
      onStatus?.call('生成失败: $e');
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

  Future<void> saveNovel(Novel novel) async {
    try {
      // 更新novels列表中的小说
      final index = novels.indexWhere((n) => n.id == novel.id);
      if (index != -1) {
        novels[index] = novel;
      } else {
        novels.add(novel);
      }

      // 保存到本地存储
      await _saveToHive(novel);
      
      // 通知UI更新
      update();
    } catch (e) {
      print('保存小说失败: $e');
      rethrow;
    }
  }

  // 短篇小说相关方法
  void toggleShortNovel(bool value) {
    isShortNovel.value = value;
    if (value) {
      // 切换到短篇时自动设置默认字数
      shortNovelWordCount.value = 15000;
    }
  }
  
  void updateShortNovelWordCount(int count) {
    if (count >= 10000 && count <= 20000) {
      shortNovelWordCount.value = count;
    } else {
      Get.snackbar('错误', '短篇小说字数必须在1万到2万字之间');
      shortNovelWordCount.value = 15000; // 设置为默认值
    }
  }

  // 修改重置生成状态的方法
  void _resetGenerationState() {
    isGenerating.value = false;
    isPaused.value = false;
    generationStatus.value = '';
  }

  // 添加 _saveChapterToHive 方法
  Future<void> _saveChapterToHive(String novelTitle, Chapter chapter) async {
    try {
      // 获取已经保存的章节列表
      final chaptersKey = 'chapters_$novelTitle';
      List<dynamic> savedChapters = _chaptersBox.get(chaptersKey, defaultValue: []) ?? [];
      
      // 检查是否存在相同编号的章节
      final index = savedChapters.indexWhere((ch) {
        if (ch is Chapter) {
          return ch.number == chapter.number;
        } else if (ch is Map) {
          return ch['number'] == chapter.number;
        }
        return false;
      });
      
      // 更新或添加章节
      if (index != -1) {
        savedChapters[index] = chapter;
      } else {
        savedChapters.add(chapter);
      }
      
      // 保存更新后的章节列表
      await _chaptersBox.put(chaptersKey, savedChapters);
      
      print('保存章节到 Hive 成功: 第${chapter.number}章 - ${chapter.title}');
    } catch (e) {
      print('保存章节到 Hive 失败: $e');
      rethrow;
    }
  }
}