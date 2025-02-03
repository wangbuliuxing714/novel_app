import 'dart:convert';
import 'package:get/get.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/services/cache_service.dart';

class OutlineController extends GetxController {
  final CacheService _cacheService = Get.find<CacheService>();
  static const String CHAPTERS_CACHE_KEY = 'chapters';
  static const String SELECTED_CHAPTER_CACHE_KEY = 'selected_chapter';
  
  final chapters = <Chapter>[].obs;
  final selectedChapterId = RxString('');
  
  @override
  void onInit() {
    super.onInit();
    _loadFromCache();
  }
  
  // 从缓存加载数据
  Future<void> _loadFromCache() async {
    try {
      final chaptersJson = _cacheService.getContent(CHAPTERS_CACHE_KEY);
      if (chaptersJson != null) {
        final List<dynamic> list = jsonDecode(chaptersJson);
        chapters.value = list.map((json) => Chapter.fromJson(json)).toList();
      }
      
      final selectedId = _cacheService.getContent(SELECTED_CHAPTER_CACHE_KEY);
      if (selectedId != null) {
        selectedChapterId.value = selectedId;
      }
    } catch (e) {
      print('加载缓存失败: $e');
    }
  }
  
  // 保存到缓存
  Future<void> _saveToCache() async {
    try {
      final chaptersJson = jsonEncode(chapters.map((chapter) => chapter.toJson()).toList());
      await _cacheService.cacheContent(CHAPTERS_CACHE_KEY, chaptersJson);
      await _cacheService.cacheContent(SELECTED_CHAPTER_CACHE_KEY, selectedChapterId.value);
    } catch (e) {
      print('保存缓存失败: $e');
    }
  }
  
  // 添加新章节，返回新章节的ID
  String addChapter(String title) {
    final newChapter = Chapter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: '',
    );
    chapters.add(newChapter);
    _saveToCache();
    return newChapter.id;  // 返回新章节的ID
  }
  
  void removeChapter(String id) {
    chapters.removeWhere((chapter) => chapter.id == id);
    if (selectedChapterId.value == id) {
      selectedChapterId.value = chapters.isNotEmpty ? chapters.first.id : '';
    }
    _saveToCache();
  }
  
  void selectChapter(String id) {
    // 更新所有章节的选中状态
    for (final chapter in chapters) {
      chapter.isSelected = chapter.id == id;
    }
    selectedChapterId.value = id;
    chapters.refresh();  // 刷新列表以更新UI
    _saveToCache();
  }
  
  void updateChapterTitle(String id, String title) {
    final chapter = chapters.firstWhereOrNull((chapter) => chapter.id == id);
    if (chapter != null) {
      chapter.title = title;
      chapters.refresh();
      _saveToCache();
    }
  }
  
  void updateChapterContent(String id, String content) {
    final chapter = chapters.firstWhereOrNull((chapter) => chapter.id == id);
    if (chapter != null) {
      chapter.content = content;
      chapters.refresh();
      _saveToCache();
    }
  }
  
  void reorderChapters(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final chapter = chapters.removeAt(oldIndex);
    chapters.insert(newIndex, chapter);
    _saveToCache();
  }
  
  Chapter? getSelectedChapter() {
    return chapters.firstWhereOrNull((chapter) => chapter.id == selectedChapterId.value);
  }
} 