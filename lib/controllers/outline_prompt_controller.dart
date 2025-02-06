import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OutlinePrompt {
  final String name;
  final String description;
  final String template;
  
  OutlinePrompt({
    required this.name,
    required this.description,
    required this.template,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'template': template,
  };

  factory OutlinePrompt.fromJson(Map<String, dynamic> json) => OutlinePrompt(
    name: json['name'],
    description: json['description'],
    template: json['template'],
  );
}

class OutlinePromptController extends GetxController {
  final RxList<OutlinePrompt> prompts = <OutlinePrompt>[].obs;
  final Rx<OutlinePrompt?> selectedPrompt = Rx<OutlinePrompt?>(null);
  late final SharedPreferences _prefs;
  final String _customPromptsKey = 'custom_outline_prompts';
  final String _selectedPromptKey = 'selected_prompt_name';
  
  // 模板变量
  static const Map<String, String> templateVariables = {
    '{title}': '小说标题',
    '{genre}': '小说类型',
    '{theme}': '主题设定',
    '{target_readers}': '目标读者',
  };

  // 基础模板结构
  String get baseTemplateStructure => '''标题：{title}
类型：{genre}
主题：{theme}
目标读者：{target_readers}

要求：
[在此添加具体要求]

大纲结构：
[在此添加大纲结构]''';

  // 获取变量说明文本
  String get variableExplanation {
    final buffer = StringBuffer('可用变量说明：\n');
    templateVariables.forEach((key, value) {
      buffer.writeln('$key - $value');
    });
    return buffer.toString();
  }

  // 默认提示词模板
  final List<OutlinePrompt> _defaultPrompts = [
    OutlinePrompt(
      name: '标准小说大纲',
      description: '适用于一般小说的标准大纲模板',
      template: '''请根据以下要求制定一个详细的小说大纲：

标题：{title}
类型：{genre}
主题：{theme}
目标读者：{target_readers}

要求：
1. 设计一个吸引人的开篇
2. 规划三个主要卷的剧情走向
3. 设计合理的装逼打脸情节
4. 安排适当的感情线发展
5. 规划主角实力提升路线
6. 设计精彩的高潮情节
7. 准备完美的结局

大纲结构：
1. 第一卷（起源）
   - 开篇设定
   - 主要人物介绍
   - 金手指获得
   - 初期发展

2. 第二卷（发展）
   - 势力扩张
   - 对手出现
   - 感情发展
   - 实力提升

3. 第三卷（高潮）
   - 最终对决
   - 感情归宿
   - 终极目标
   - 圆满结局''',
    ),
    OutlinePrompt(
      name: '都市爽文大纲',
      description: '适用于都市爽文的大纲模板',
      template: '''请根据以下要求制定一个都市爽文的详细大纲：

标题：{title}
类型：{genre}
主题：{theme}
目标读者：{target_readers}

要求：
1. 设计一个平凡但有潜力的主角背景
2. 安排各种打脸装逼的情节
3. 设计商战、职场的冲突
4. 规划感情线和红颜知己
5. 设计主角能力提升路线
6. 准备各种逆袭打脸的高潮
7. 规划圆满的结局

大纲结构：
1. 第一卷（逆袭）
   - 主角背景
   - 机遇获得
   - 初期打脸
   - 事业起步

2. 第二卷（崛起）
   - 商业扩张
   - 情感发展
   - 势力对抗
   - 地位提升

3. 第三卷（巅峰）
   - 终极对决
   - 情感圆满
   - 事业成功
   - 走向巅峰''',
    ),
  ];

  Future<void> init() async {
    _prefs = Get.find<SharedPreferences>();
    await _loadPrompts();
    _loadSelectedPrompt();
  }

  void _loadSelectedPrompt() {
    final savedName = _prefs.getString(_selectedPromptKey);
    if (savedName != null) {
      selectedPrompt.value = prompts.firstWhereOrNull((p) => p.name == savedName);
    }
    // 如果没有选中的模板，默认选择第一个
    selectedPrompt.value ??= prompts.firstOrNull;
  }

  Future<void> setSelectedPrompt(String promptName) async {
    final prompt = prompts.firstWhereOrNull((p) => p.name == promptName);
    if (prompt != null) {
      selectedPrompt.value = prompt;
      await _prefs.setString(_selectedPromptKey, promptName);
    }
  }

  // 获取当前选中的提示词模板
  String get currentTemplate {
    return selectedPrompt.value?.template ?? _defaultPrompts[0].template;
  }

  Future<void> _loadPrompts() async {
    try {
      // 清空当前列表
      prompts.clear();
      
      // 首先加载默认模板
      prompts.addAll(_defaultPrompts);
      
      // 然后加载自定义模板
      final customPromptsJson = _prefs.getString(_customPromptsKey);
      if (customPromptsJson != null) {
        final List<dynamic> customPromptsList = jsonDecode(customPromptsJson);
        final List<OutlinePrompt> customPrompts = customPromptsList
            .map((json) => OutlinePrompt.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        prompts.addAll(customPrompts);
      }
      
      print('成功加载 ${prompts.length} 个提示词模板');
    } catch (e) {
      print('加载提示词模板失败: $e');
    }
  }

  Future<void> _saveCustomPrompts() async {
    try {
      final customPrompts = prompts
          .where((prompt) => !_isDefaultPrompt(prompt.name))
          .toList();
      
      final customPromptsJson = jsonEncode(
        customPrompts.map((prompt) => prompt.toJson()).toList(),
      );
      
      await _prefs.setString(_customPromptsKey, customPromptsJson);
      print('成功保存 ${customPrompts.length} 个自定义提示词模板');
    } catch (e) {
      print('保存提示词模板失败: $e');
      rethrow;
    }
  }

  bool _isDefaultPrompt(String promptName) {
    final isDefault = _defaultPrompts.any((prompt) => prompt.name == promptName);
    print('检查是否为默认提示词: $promptName - $isDefault');
    return isDefault;
  }

  bool isDefaultPrompt(String promptName) {
    return _isDefaultPrompt(promptName);
  }

  Future<void> addPrompt(OutlinePrompt prompt) async {
    if (!prompts.any((p) => p.name == prompt.name)) {
      prompts.add(prompt);
      await _saveCustomPrompts();
    }
  }

  Future<void> updatePrompt(int index, OutlinePrompt newPrompt) async {
    try {
      final currentPrompt = prompts[index];
      final isDefault = _isDefaultPrompt(currentPrompt.name);
      print('正在更新提示词：${currentPrompt.name}');
      print('是否为默认提示词：$isDefault');
      
      if (!isDefault) {
        print('开始更新提示词...');
        prompts[index] = newPrompt;
        await _saveCustomPrompts();
        print('提示词更新成功！');
      } else {
        print('无法编辑默认提示词');
        throw Exception('默认提示词模板不可编辑');
      }
    } catch (e) {
      print('更新提示词失败: $e');
      rethrow;
    }
  }

  Future<void> deletePrompt(int index) async {
    if (!_isDefaultPrompt(prompts[index].name)) {
      prompts.removeAt(index);
      await _saveCustomPrompts();
    }
  }
} 