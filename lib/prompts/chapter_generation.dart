// 章节生成相关文件
// 包含章节生成的系统提示词、具体提示词和生成方法
// 在 NovelGeneratorService 中被使用

import 'master_prompts.dart';

class ChapterGeneration {
  /// 章节生成的系统提示词
  static String getSystemPrompt(String style) => '''
${MasterPrompts.basicPrinciples}

以$style的风格创作本章节，请注意：

1. 内容要求：
   - 按照大纲发展情节
   - 保持前后连贯性
   - 为后续做好铺垫

2. 结构要求：
   - 段落重点突出
   - 合理安排节奏
   - 结尾留有悬念

3. 写作风格：
   - 保持$style特色
   - 语言生动准确
   - 叙事视角一致

4. 格式要求：
   - 段落间空行
   - 避免特殊符号
   - 保持格式规范
''';

  /// 章节生成的具体提示词
  static String getChapterPrompt({
    required String title,
    required int chapterNumber,
    required String outline,
    required List<String> previousChapters,
    required int totalChapters,
    required String genre,
    required String theme,
    required String style,
  }) => '''
创作《$title》第 $chapterNumber 章（共$totalChapters章）

信息：
- 类型：$genre
- 主题：$theme
- 风格：$style

大纲：
$outline

${previousChapters.isNotEmpty ? '''上章概要：
${previousChapters.last}''' : ''}

要求：
1. 按大纲发展
2. 场景要具体
3. 对话要传神
4. 前后连贯
5. 为后文铺垫
''';

  /// 章节格式化方法
  static String formatChapter(String rawChapter) {
    // 移除多余的空行和特殊字符
    final lines = rawChapter
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    
    // 格式化处理
    final formattedLines = <String>[];
    var previousLineIsTitle = false;
    
    for (var line in lines) {
      // 移除章节标题标记
      if (line.startsWith('第') && line.contains('章')) {
        continue;
      }
      
      // 移除特殊字符
      line = line.replaceAll(RegExp(r'[#\*]'), '');
      
      // 处理段落间距
      if (!previousLineIsTitle && line.isNotEmpty) {
        formattedLines.add('');
      }
      
      formattedLines.add(line);
      previousLineIsTitle = line.endsWith('：') || line.endsWith(':');
    }
    
    return formattedLines.join('\n').trim();
  }
} 