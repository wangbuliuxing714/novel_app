import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CacheService extends GetxService {
  static const String CACHE_KEY_PREFIX = 'novel_cache_';
  static const String STYLE_CACHE_KEY = 'style_cache_';
  static const String PATTERN_CACHE_KEY = 'pattern_cache_';
  static const String CHAT_SESSION_BOX = 'chat_sessions';
  static const String CHAT_CONTEXT_BOX = 'chat_contexts';
  
  final SharedPreferences _prefs;
  bool _hiveInitialized = false;

  CacheService(this._prefs);

  @override
  void onInit() {
    super.onInit();
    _initHive();
  }

  // 初始化Hive
  Future<void> _initHive() async {
    try {
      if (!_hiveInitialized) {
        final appDocumentDir = await getApplicationDocumentsDirectory();
        Hive.init(appDocumentDir.path);
        await Hive.openBox(CHAT_SESSION_BOX);
        await Hive.openBox(CHAT_CONTEXT_BOX);
        _hiveInitialized = true;
      }
    } catch (e) {
      print('初始化Hive失败: $e');
    }
  }

  // 打开聊天会话盒子
  Future<Box> openChatSessionBox() async {
    if (!_hiveInitialized) {
      await _initHive();
    }
    return Hive.box(CHAT_SESSION_BOX);
  }

  // 打开聊天上下文盒子
  Future<Box> openChatContextBox() async {
    if (!_hiveInitialized) {
      await _initHive();
    }
    return Hive.box(CHAT_CONTEXT_BOX);
  }

  // 缓存生成的内容
  Future<void> cacheContent(String key, String content) async {
    await _prefs.setString('$CACHE_KEY_PREFIX$key', content);
  }

  // 获取缓存的内容
  String? getContent(String key) {
    return _prefs.getString('$CACHE_KEY_PREFIX$key');
  }

  // 缓存写作风格模式
  Future<void> cacheStylePattern(String style, List<String> patterns) async {
    await _prefs.setString('$STYLE_CACHE_KEY$style', jsonEncode(patterns));
  }

  // 获取写作风格模式
  List<String>? getStylePatterns(String style) {
    final patternsJson = _prefs.getString('$STYLE_CACHE_KEY$style');
    if (patternsJson == null) return null;
    return List<String>.from(jsonDecode(patternsJson));
  }

  // 缓存成功的段落模式
  Future<void> cacheSuccessfulPattern(String pattern) async {
    final patterns = getSuccessfulPatterns();
    if (!patterns.contains(pattern)) {
      patterns.add(pattern);
      await _prefs.setStringList(PATTERN_CACHE_KEY, patterns);
    }
  }

  // 获取成功的段落模式
  List<String> getSuccessfulPatterns() {
    return _prefs.getStringList(PATTERN_CACHE_KEY) ?? [];
  }

  // 检查内容是否重复
  bool isContentDuplicate(String content, List<String> previousContents) {
    // 将内容分成段落
    final paragraphs = content.split('\n\n');
    
    // 检查每个段落是否在之前的内容中重复出现
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;
      
      for (final previousContent in previousContents) {
        if (previousContent.contains(paragraph)) {
          return true;
        }
      }
    }
    
    return false;
  }

  // 清除特定键的缓存
  Future<void> clearCache(String key) async {
    await _prefs.remove('$CACHE_KEY_PREFIX$key');
  }

  // 清除所有缓存
  Future<void> clearAllCache() async {
    final keys = _prefs.getKeys().where((key) => 
      key.startsWith(CACHE_KEY_PREFIX) || 
      key.startsWith(STYLE_CACHE_KEY) ||
      key == PATTERN_CACHE_KEY
    );
    
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  // 添加删除内容的方法
  Future<void> removeContent(String key) async {
    try {
      await _prefs.remove(key);
    } catch (e) {
      print('删除缓存失败: $e');
    }
  }
  
  // 清除所有聊天会话
  Future<void> clearAllChatSessions() async {
    try {
      final sessionBox = await openChatSessionBox();
      final contextBox = await openChatContextBox();
      
      await sessionBox.clear();
      await contextBox.clear();
    } catch (e) {
      print('清除聊天会话失败: $e');
    }
  }
} 