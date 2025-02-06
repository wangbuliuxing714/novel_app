import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/genre_category.dart';
import 'package:novel_app/services/novel_generator_service.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/services/export_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class NovelController extends GetxController {
  final _novelGenerator = Get.find<NovelGeneratorService>();
  final _cacheService = Get.find<CacheService>();
  final _exportService = ExportService();
  final novels = <Novel>[].obs;
  
  final title = ''.obs;
  final mainCharacter = ''.obs;
  final femaleCharacter = ''.obs;
  final background = ''.obs;
  final otherRequirements = ''.obs;
  final style = '轻松幽默'.obs;
  final totalChapters = 1.obs;
  final selectedGenres = <String>[].obs;
  
  final isGenerating = false.obs;
  final generationStatus = ''.obs;
  final generationProgress = 0.0.obs;

  static const _boxName = 'generated_chapters';
  late final Box<dynamic> _box;
  
  final RxList<Chapter> _generatedChapters = <Chapter>[].obs;

  List<Chapter> get generatedChapters => _generatedChapters;

  @override
  void onInit() async {
    super.onInit();
    await _initHive();
    _loadChapters();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  void _loadChapters() {
    final savedChapters = _box.get('chapters');
    if (savedChapters != null) {
      final List<dynamic> chaptersJson = jsonDecode(savedChapters);
      _generatedChapters.value = chaptersJson
          .map((json) => Chapter.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      _sortChapters();
    }
  }

  Future<void> _saveChapters() async {
    final chaptersJson = jsonEncode(
      _generatedChapters.map((chapter) => chapter.toJson()).toList(),
    );
    await _box.put('chapters', chaptersJson);
  }

  void updateTitle(String value) => title.value = value;
  void updateMainCharacter(String value) => mainCharacter.value = value;
  void updateFemaleCharacter(String value) => femaleCharacter.value = value;
  void updateBackground(String value) => background.value = value;
  void updateOtherRequirements(String value) => otherRequirements.value = value;
  void updateStyle(String value) => style.value = value;
  void updateTotalChapters(int value) => totalChapters.value = value;

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

  Future<void> generateNovel({bool continueGeneration = false}) async {
    if (title.isEmpty) {
      Get.snackbar('错误', '请输入小说标题');
      return;
    }

    if (selectedGenres.isEmpty) {
      Get.snackbar('错误', '请选择至少一个小说类型');
      return;
    }

    if (mainCharacter.isEmpty) {
      Get.snackbar('错误', '请输入主角设定');
      return;
    }

    // 构建完整的创作要求
    final theme = '''主角设定：${mainCharacter.value}
女主角设定：${femaleCharacter.value}
故事背景：${background.value}
其他要求：${otherRequirements.value}''';

    isGenerating.value = true;
    generationProgress.value = 0;

    try {
      final novel = await _novelGenerator.generateNovel(
        title: title.value,
        genre: selectedGenres.join('、'),
        theme: theme,
        targetReaders: '青年读者',
        totalChapters: totalChapters.value,
        continueGeneration: continueGeneration,
        onProgress: (status) {
          generationStatus.value = status;
          if (status.contains('正在生成大纲')) {
            generationProgress.value = 0.2;
          } else if (status.contains('正在生成第')) {
            final currentChapter = int.tryParse(
                  status.split('第')[1].split('章')[0].trim(),
                ) ??
                0;
            generationProgress.value =
                0.2 + 0.8 * (currentChapter / totalChapters.value);
          }
        },
      );

      novels.insert(0, novel);
      Get.snackbar('成功', '小说生成完成');
    } catch (e) {
      Get.snackbar('错误', '生成失败：$e');
    } finally {
      isGenerating.value = false;
      generationProgress.value = 0;
      generationStatus.value = '';
    }
  }

  void addChapter(Chapter chapter) {
    _generatedChapters.add(chapter);
    _sortChapters();
    _saveChapters();
  }

  void deleteChapter(int chapterNumber) {
    _generatedChapters.removeWhere((chapter) => chapter.number == chapterNumber);
    _saveChapters();
  }

  void clearAllChapters() {
    _generatedChapters.clear();
    _saveChapters();
  }

  void updateChapter(Chapter chapter) {
    final index = _generatedChapters.indexWhere((c) => c.number == chapter.number);
    if (index != -1) {
      _generatedChapters[index] = chapter;
      _saveChapters();
    }
  }

  Chapter? getChapter(int chapterNumber) {
    return _generatedChapters.firstWhereOrNull((chapter) => chapter.number == chapterNumber);
  }

  void _sortChapters() {
    _generatedChapters.sort((a, b) => a.number.compareTo(b.number));
  }

  Future<String> exportChapters() async {
    try {
      if (_generatedChapters.isEmpty) {
        return '没有可导出的章节';
      }

      return await _exportService.exportChapters(
        _generatedChapters,
        'txt',  // 默认使用txt格式
        title: title.value,
      );
    } catch (e) {
      return '导出失败：$e';
    }
  }

  // 在生成新章节时自动添加到存储
  Future<Chapter> generateChapter(int chapterNumber) async {
    try {
      final chapter = await _novelGenerator.generateChapter(
        title: '第 $chapterNumber 章',
        number: chapterNumber,
        outline: novels.first.outline,
        previousChapters: _generatedChapters.toList(),
        totalChapters: totalChapters.value,
        genre: selectedGenres.join('、'),
        theme: '''主角设定：${mainCharacter.value}
女主角设定：${femaleCharacter.value}
故事背景：${background.value}
其他要求：${otherRequirements.value}''',
        onProgress: (status) {
          generationStatus.value = status;
        },
      );
      
      // 自动添加到存储
      addChapter(chapter);
      
      return chapter;
    } catch (e) {
      print('生成章节失败: $e');
      rethrow;
    }
  }

  // 开始生成
  void startGeneration() {
    if (isGenerating.value) return;
    isGenerating.value = true;
    // 清空已生成的章节
    clearAllChapters();
    generateNovel();
  }

  // 停止生成
  void stopGeneration() {
    isGenerating.value = false;
  }
}