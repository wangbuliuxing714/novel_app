// 剧集生成相关文件
// 包含剧集生成的系统提示词、具体提示词和生成方法
// 在 NovelGeneratorService 中被使用

import 'master_prompts.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/prompts/female_prompts.dart';
import 'package:novel_app/prompts/male_prompts.dart';

class ChapterGeneration {
  /// 剧集生成的系统提示词
  static String getSystemPrompt(String style) => '''
${MasterPrompts.basicPrinciples}

以$style的风格创作本剧集，请注意：

1. 内容要求：
   - 按照大纲发展情节
   - 保持前后连贯性
   - 为后续做好铺垫
   - 结尾设置悬念

2. 结构要求：
   - 场景描述简洁明了
   - 对白生动自然
   - 动作描写清晰
   - 合理安排节奏

3. 写作风格：
   - 保持$style特色
   - 语言生动准确
   - 符合短剧快节奏特点

4. 格式要求：
   - 严格遵循标准剧本格式
   - 场景标题格式：场景编号-场景位置 时间 内/外
   - 人物对白前标明人物名称
   - 动作描写使用△符号开头
   - 镜头指示使用【】括起来
   - 旁白使用（VO）标注
   - 内心独白使用（OS）标注
''';

  /// 增强版系统提示词，强调前后连贯性
  static String getSystemPromptWithContinuity(String style, bool hasPreEpisodes) => '''
${MasterPrompts.basicPrinciples}

以$style的风格创作本剧集，请注意：

1. 内容要求：
   - 严格按照大纲发展情节
   - 严格保持与前几集的情节连贯性
   - 确保人物性格、世界观和设定保持一致
   - 为后续剧情做好铺垫
   - 结尾设置悬念

2. 结构要求：
   - 场景描述简洁明了
   - 对白生动自然，符合人物性格特点
   - 动作描写清晰，避免前后矛盾
   - 合理安排节奏
   - 承接前几集未完成的情节线

3. 写作风格：
   - 保持$style特色
   - 语言生动准确
   - 符合短剧快节奏特点
   - 保持情节的连贯性和吸引力

4. 格式要求：
   - 严格遵循标准剧本格式
   - 场景标题格式：场景编号-场景位置 时间 内/外
   - 人物对白前标明人物名称
   - 动作描写使用△符号开头
   - 镜头指示使用【】括起来
   - 旁白使用（VO）标注
   - 内心独白使用（OS）标注

${hasPreEpisodes ? '5. 上下文连贯：\n   - 认真阅读之前剧集的内容摘要\n   - 确保本集与前几集的情节、设定和人物关系保持一致\n   - 处理好前几集留下的悬念\n   - 保持角色动机和性格的一致性' : ''}
''';

  /// 剧集生成的具体提示词
  static String getEpisodePrompt({
    required String title,
    required int episodeNumber,
    required int totalEpisodes,
    required String outline,
    required List<dynamic> previousEpisodes,
    required String genre,
    required String theme,
    required String style,
    String? targetViewers,
  }) {
    // 根据目标观众选择不同的提示词
    if (targetViewers == '女性向') {
      return FemalePrompts.getChapterPrompt(
        title, 
        genre, 
        episodeNumber, 
        totalEpisodes, 
        _extractEpisodeTitle(outline, episodeNumber),
        _extractEpisodeOutline(outline, episodeNumber)
      );
    } else {
      return MalePrompts.getChapterPrompt(
        title, 
        genre, 
        episodeNumber, 
        totalEpisodes, 
        _extractEpisodeTitle(outline, episodeNumber),
        _extractEpisodeOutline(outline, episodeNumber)
      );
    }
  }
  
  /// 从大纲中提取剧集标题
  static String _extractEpisodeTitle(String outline, int episodeNumber) {
    // 尝试匹配"第X集：标题"或"第X集 标题"格式
    final RegExp titleRegex = RegExp(r'第' + episodeNumber.toString() + r'集[：\s]+(.*?)[\n\r]');
    final match = titleRegex.firstMatch(outline);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? '第$episodeNumber集';
    }
    return '第$episodeNumber集';
  }
  
  /// 从大纲中提取剧集内容
  static String _extractEpisodeOutline(String outline, int episodeNumber) {
    // 尝试匹配第N集的整个内容块
    final RegExp episodeRegex = RegExp(r'第' + episodeNumber.toString() + r'集.*?(?=第' + (episodeNumber + 1).toString() + r'集|$)', dotAll: true);
    final match = episodeRegex.firstMatch(outline);
    if (match != null) {
      return match.group(0) ?? '';
    }
    return '';
  }

  /// 公共方法：从大纲中提取剧集标题
  static String extractEpisodeTitle(String outline, int episodeNumber) {
    return _extractEpisodeTitle(outline, episodeNumber);
  }
  
  /// 公共方法：从大纲中提取剧集内容
  static String extractEpisodeOutline(String outline, int episodeNumber) {
    return _extractEpisodeOutline(outline, episodeNumber);
  }

  /// 剧本格式化方法
  static String formatScript(String rawScript) {
    // 清理生成的内容，保留剧本格式
    String cleaned = rawScript.trim();
    
    // 移除可能的剧集标题（如果AI生成了标题）
    if (cleaned.startsWith('第') && cleaned.contains('集')) {
      final titleEndIndex = cleaned.indexOf('\n');
      if (titleEndIndex > 0) {
        cleaned = cleaned.substring(titleEndIndex).trim();
      }
    }
    
    // 移除多余的空行
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return cleaned;
  }
  
  /// 生成短剧脚本的提示词
  static String generateScriptPrompt({
    required String title,
    required int episodeNumber,
    required String outline,
    required String genre,
    required List<String> characters,
    required String episodeTitle,
  }) {
    return '''
请根据以下信息创作一集短剧脚本：

短剧标题：《$title》
剧集编号：第$episodeNumber集
剧集标题：$episodeTitle
类型：$genre
主要人物：${characters.join('、')}

剧集大纲：
$outline

请按照以下标准短剧脚本格式创作：

1. 场景标题格式：场景编号-场景位置 时间 内/外
   例如：1-1 公司楼下 日 外

2. 场景下方列出出场人物
   例如：出场人物：张三、李四、王五

3. 场景描述简洁明了，使用△符号开头
   例如：△张三走进办公室，环顾四周

4. 人物对白前标明人物名称
   例如：张三：你好，我是新来的员工

5. 动作描写使用△符号开头
   例如：△李四站起身，伸出手

6. 镜头指示使用【】括起来
   例如：【特写】【切镜头】【闪回】

7. 旁白使用（VO）标注
   例如：张三（VO）：那一天，我的生活彻底改变了

8. 内心独白使用（OS）标注
   例如：李四（OS）：他看起来很面熟

9. 每个场景结束后空一行

10. 在适当位置设置悬念和付费点

请确保脚本风格符合短剧特点：节奏紧凑、对白简练、情节引人入胜。
''';
  }
  
  /// 带有上下文的短剧脚本提示词
  static String generateScriptPromptWithContext({
    required String title,
    required int episodeNumber,
    required String outline,
    required String genre,
    required List<String> characters,
    required String episodeTitle,
    String previousEpisodesSummary = '',
  }) {
    String basePrompt = '''
请根据以下信息创作一集短剧脚本：

短剧标题：《$title》
剧集编号：第$episodeNumber集
剧集标题：$episodeTitle
类型：$genre
主要人物：${characters.join('、')}

剧集大纲：
$outline
''';

    // 如果有前集摘要，添加到提示词中
    if (previousEpisodesSummary.isNotEmpty) {
      basePrompt += '''

$previousEpisodesSummary

请确保本集内容与前几集保持情节连贯性，人物形象和剧情发展一致。避免出现前后矛盾的情节或人物行为。
''';
    }

    basePrompt += '''

请按照以下标准短剧脚本格式创作：

1. 场景标题格式：场景编号-场景位置 时间 内/外
   例如：1-1 公司楼下 日 外

2. 场景下方列出出场人物
   例如：出场人物：张三、李四、王五

3. 场景描述简洁明了，使用△符号开头
   例如：△张三走进办公室，环顾四周

4. 人物对白前标明人物名称
   例如：张三：你好，我是新来的员工

5. 动作描写使用△符号开头
   例如：△李四站起身，伸出手

6. 镜头指示使用【】括起来
   例如：【特写】【切镜头】【闪回】

7. 旁白使用（VO）标注
   例如：张三（VO）：那一天，我的生活彻底改变了

8. 内心独白使用（OS）标注
   例如：李四（OS）：他看起来很面熟

9. 每个场景结束后空一行

10. 在适当位置设置悬念和付费点

请确保脚本风格符合短剧特点：节奏紧凑、对白简练、情节引人入胜。同时，保持与前几集的情节连贯性，确保人物性格、动机和行为的一致性。
''';

    return basePrompt;
  }
} 