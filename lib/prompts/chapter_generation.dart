// 章节生成相关文件
// 包含章节生成的系统提示词、具体提示词和生成方法
// 在 NovelGeneratorService 中被使用

import 'master_prompts.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/prompts/female_prompts.dart';
import 'package:novel_app/prompts/male_prompts.dart';

class ChapterGeneration {
  /// 章节生成的系统提示词
  static String getSystemPrompt(String style) => '''
${MasterPrompts.basicPrinciples}

以$style的风格创作本章节，请注意：

1. 内容要求：
   - 严格按照大纲发展情节
   - 保持与前文的严格连贯性
   - 参考所有前文内容，确保人物、情节、设定一致
   - 为后续做好铺垫

2. 结构要求：
   - 段落重点突出
   - 合理安排节奏
   - 结尾留有悬念

3. 写作风格：
   - 保持$style特色
   - 语言生动准确
   - 叙事视角一致

4. 前文记忆与连贯性：
   - 准确记住前文中的所有关键情节
   - 延续前文中人物的性格发展和关系变化
   - 正确引用前文中提及的特定物品、地点和概念
   - 确保世界观和设定的一致性
   - 延续前文的写作风格和语言习惯

5. 格式要求：
   - 段落间空行
   - 避免特殊符号
   - 保持格式规范
''';

  /// 章节生成的具体提示词
  static String getChapterPrompt({
    required String title,
    required int chapterNumber,
    required int totalChapters,
    required String outline,
    required List<dynamic> previousChapters,
    required String genre,
    required String theme,
    required String style,
    String? targetReaders,
  }) {
    // 根据目标读者选择不同的提示词
    if (targetReaders == '女性向') {
      return FemalePrompts.getChapterPrompt(
        title, 
        genre, 
        chapterNumber, 
        totalChapters, 
        _extractChapterTitle(outline, chapterNumber),
        _extractChapterOutline(outline, chapterNumber)
      );
    } else {
      return MalePrompts.getChapterPrompt(
        title, 
        genre, 
        chapterNumber, 
        totalChapters, 
        _extractChapterTitle(outline, chapterNumber),
        _extractChapterOutline(outline, chapterNumber)
      );
    }
  }
  
  /// 从大纲中提取章节标题
  static String _extractChapterTitle(String outline, int chapterNumber) {
    // 尝试匹配"第X章：标题"或"第X章 标题"格式
    final RegExp titleRegex = RegExp(r'第' + chapterNumber.toString() + r'章[：\s]+(.*?)[\n\r]');
    final match = titleRegex.firstMatch(outline);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? '第$chapterNumber章';
    }
    return '第$chapterNumber章';
  }
  
  /// 从大纲中提取章节内容
  static String _extractChapterOutline(String outline, int chapterNumber) {
    // 尝试匹配第N章的整个内容块
    final RegExp chapterRegex = RegExp(r'第' + chapterNumber.toString() + r'章.*?(?=第' + (chapterNumber + 1).toString() + r'章|$)', dotAll: true);
    final match = chapterRegex.firstMatch(outline);
    if (match != null) {
      return match.group(0) ?? '';
    }
    return '';
  }

  /// 章节格式化方法
  static String formatChapter(String rawChapter) {
    // 清理生成的内容，移除可能的标题和多余的空行
    String cleaned = rawChapter.trim();
    
    // 移除可能的章节标题（如果AI生成了标题）
    if (cleaned.startsWith('第') && cleaned.contains('章')) {
      final titleEndIndex = cleaned.indexOf('\n');
      if (titleEndIndex > 0) {
        cleaned = cleaned.substring(titleEndIndex).trim();
      }
    }
    
    // 移除多余的空行
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return cleaned;
  }
} 