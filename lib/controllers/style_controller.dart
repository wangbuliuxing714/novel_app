import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WritingStyle {
  final String name;
  final String description;
  final String prompt;
  
  WritingStyle({
    required this.name,
    required this.description,
    required this.prompt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'prompt': prompt,
  };

  factory WritingStyle.fromJson(Map<String, dynamic> json) => WritingStyle(
    name: json['name'],
    description: json['description'],
    prompt: json['prompt'],
  );
}

class StyleController extends GetxController {
  final RxList<WritingStyle> styles = <WritingStyle>[].obs;
  final _prefs = Get.find<SharedPreferences>();
  final String _customStylesKey = 'custom_styles';
  
  // 默认写作风格
  final List<WritingStyle> _defaultStyles = [
    WritingStyle(
      name: '硬核爽文',
      description: '强调剧情张力和爽感的写作风格',
      prompt: '注重情节紧凑、高潮迭起，突出主角的强大和成长',
    ),
    WritingStyle(
      name: '轻松幽默',
      description: '轻松愉快的写作风格',
      prompt: '以轻松诙谐的笔调展开故事，适当加入幽默元素',
    ),
    WritingStyle(
      name: '严肃正经',
      description: '严谨认真的写作风格',
      prompt: '以严谨的笔调展开故事，注重逻辑性和真实感',
    ),
    WritingStyle(
      name: '悬疑烧脑',
      description: '充满悬念的写作风格',
      prompt: '以悬疑的笔调展开故事，设置多重谜题和伏笔',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    _loadStyles();
  }

  void _loadStyles() {
    // 首先加载默认风格
    styles.addAll(_defaultStyles);
    
    // 然后加载自定义风格
    final customStylesJson = _prefs.getString(_customStylesKey);
    if (customStylesJson != null) {
      try {
        final List<dynamic> customStylesList = jsonDecode(customStylesJson);
        final List<WritingStyle> customStyles = customStylesList
            .map((json) => WritingStyle.fromJson(json))
            .toList();
        styles.addAll(customStyles);
      } catch (e) {
        print('加载自定义写作风格失败: $e');
      }
    }
  }

  void _saveCustomStyles() {
    final customStyles = styles
        .where((style) => !_isDefaultStyle(style.name))
        .toList();
    
    final customStylesJson = jsonEncode(
      customStyles.map((style) => style.toJson()).toList(),
    );
    
    _prefs.setString(_customStylesKey, customStylesJson);
  }

  bool _isDefaultStyle(String styleName) {
    return _defaultStyles.any((style) => style.name == styleName);
  }

  bool isDefaultStyle(String styleName) {
    return _isDefaultStyle(styleName);
  }

  void addStyle(WritingStyle style) {
    if (!styles.any((s) => s.name == style.name)) {
      styles.add(style);
      _saveCustomStyles();
    }
  }

  void updateStyle(int index, WritingStyle newStyle) {
    if (!_isDefaultStyle(styles[index].name)) {
      styles[index] = newStyle;
      _saveCustomStyles();
    }
  }

  void deleteStyle(int index) {
    if (!_isDefaultStyle(styles[index].name)) {
      styles.removeAt(index);
      _saveCustomStyles();
    }
  }
} 