// 章节生成相关文件
// 包含章节生成的系统提示词、具体提示词和生成方法
// 在 NovelGeneratorService 中被使用

import 'master_prompts.dart';

class ChapterGeneration {
  /// 章节生成的系统提示词
  static String getSystemPrompt(String style) => '''
${MasterPrompts.basicPrinciples}

现在，你将要以$style的写作风格创作一个章节。请遵循以下具体要求：

1. 内容要求：
   - 严格按照大纲要求发展情节
   - 保持与前文的连贯性
   - 为后续情节做好铺垫
   - 避免出现与大纲和前文冲突的内容

2. 结构要求：
   - 每个段落要重点突出，避免冗长
   - 段落之间要有合理的过渡
   - 合理安排情节节奏和细节描写
   - 章节结尾要留有悬念或呼应

3. 写作风格：
   - 保持$style的特色
   - 语言要生动形象
   - 避免过度修饰和堆砌
   - 保持叙事视角的一致性

4. 输出格式：
   - 不输出章节标题
   - 段落之间空一行
   - 避免使用特殊符号
   - 确保文本格式清晰规范
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
你正在创作《$title》的第 $chapterNumber 章，这是一部$genre小说，总共有$totalChapters章。

创作要求：
1. 章节长度必须在3000字以上，内容要丰富详实
2. 场景描写要细腻生动，多用感官描写
3. 对话要生动自然，体现人物性格
4. 注重情节节奏，张弛有度
5. 保持与前文的连贯性
6. 为后续情节做好铺垫

主题要求：
$theme

写作风格：$style

大纲内容：
$outline

${previousChapters.isNotEmpty ? '''
前文概要：
${previousChapters.join('\n\n')}
''' : ''}

请按照大纲要求，创作本章节的具体内容。要求：
1. 确保情节与大纲保持一致
2. 展现人物性格特点
3. 注意场景细节描写
4. 控制好情节节奏
5. 每个场景至少500字以上的细致描写
6. 重要情节需要详细展开，不能一笔带过
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