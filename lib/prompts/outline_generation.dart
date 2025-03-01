// 大纲生成相关文件
// 包含大纲生成的系统提示词、具体提示词和生成方法
// 在 NovelGeneratorService 中被使用

import 'master_prompts.dart';

class OutlineGeneration {
  /// 大纲生成的系统提示词
  static String getSystemPrompt(String title, String genre, String theme) => '''
${MasterPrompts.basicPrinciples}

现在，你将要为一部题为《$title》的$genre小说创作分层大纲。
主题与要求：$theme

请遵循以下大纲创作原则：

1. 整体架构设计：
   - 设计完整的三幕式结构（开端、发展、高潮）
   - 确保主线清晰，支线丰富但不喧宾夺主
   - 设计合理的情节递进和高潮分布
   - 确保每个转折点都有充分的铺垫

2. 主线设计：
   - 明确故事的核心冲突
   - 设计清晰的矛盾发展脉络
   - 安排关键的转折点和高潮
   - 设计令人满意的结局

3. 支线设计：
   - 支线要服务于主线或主题
   - 设计多样化的支线类型（感情线、成长线等）
   - 合理安排支线的出现和结束时机
   - 确保支线之间有适当的交织和呼应

4. 人物发展规划：
   - 设计主要人物的成长轨迹
   - 安排重要的性格转折点
   - 设计人物关系的发展变化
   - 确保人物行为的合理性

5. 节奏控制：
   - 设计合理的起伏节奏
   - 安排适当的悬念和高潮
   - 控制情节发展的速度
   - 预留足够的铺垫和回顾空间
''';

  /// 大纲生成的具体提示词
  static String getOutlinePrompt(String title, String genre, String theme, int totalChapters) => '''
请为这部名为《$title》的$genre小说创作一个分层的$totalChapters章节大纲。

创作要求：
$theme

大纲格式要求：
1. 第一层：整体架构（三幕式结构）
   - 开端（约占20%）：介绍背景、人物、核心冲突
   - 发展（约占60%）：矛盾升级、情节推进、人物成长
   - 高潮（约占20%）：最终决战、结局呈现

2. 第二层：主要情节线
   - 主线：核心冲突的发展脉络
   - 支线A：重要人物关系发展
   - 支线B：次要矛盾发展
   （根据需要可以有更多支线）

3. 第三层：具体章节
   每章需包含：
   - 章节标题（简洁有力）
   - 主要情节（2-3个关键点）
   - 次要情节（1-2个补充点）
   - 人物发展（重要人物的变化）
   - 伏笔/悬念（如果有）

请按照以下格式输出：

一、整体架构
[详细说明三幕式结构的具体内容]

二、主要情节线
[列出主线和重要支线的发展脉络]

三、具体章节
第1章：章节标题
主要情节：
- 情节点1
- 情节点2
次要情节：
- 情节点A
人物发展：
- 变化点1
伏笔/悬念：
- 伏笔点1

第2章：...（后续章节）
''';

  /// 大纲格式化方法
  static String formatOutline(String rawOutline) {
    // 移除多余的空行
    final lines = rawOutline.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // 格式化处理
    final formattedLines = <String>[];
    var inChapterSection = false;
    
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      
      // 处理主要分段标题
      if (line.startsWith('一、') || line.startsWith('二、') || line.startsWith('三、')) {
        if (i > 0) formattedLines.add('');
        formattedLines.add(line);
        formattedLines.add('');
        continue;
      }
      
      // 处理章节标题
      if (line.startsWith('第') && line.contains('章：')) {
        inChapterSection = true;
        if (i > 0) formattedLines.add('');
        formattedLines.add(line);
        continue;
      }
      
      // 处理章节内容
      if (inChapterSection) {
        if (line.endsWith('：')) {
          if (i > 0) formattedLines.add('');
          formattedLines.add(line);
        } else if (line.startsWith('-')) {
          formattedLines.add('  $line');
        } else {
          formattedLines.add(line);
        }
        continue;
      }
      
      formattedLines.add(line);
    }
    
    return formattedLines.join('\n');
  }

  static String generateOutlinePrompt(String title, String genre, String theme, String targetReaders, int totalChapters) {
    return '''
${MasterPrompts.expectationPrompt}

请根据以下信息创作一部小说的大纲：

小说标题：$title
小说类型：$genre
主题与背景：$theme
目标读者：$targetReaders
总章节数：$totalChapters

要求：
1. 创建一个引人入胜的故事大纲，包含总体故事梗概和每章内容概述
2. 确保故事有明确的起承转合，情节发展合理
3. 每个章节都要包含至少一种期待感类型（展现价值型或矛盾冲突型）
4. 主角的价值被埋没后，最终能够得到展现
5. 矛盾冲突能够层层递进，不断升级
6. 在关键情节点上，通过期待感的满足给读者带来情感共鸣
7. 章节标题要吸引人，能够引起读者的好奇心
8. 每章概述应包含200-300字左右的内容，详细说明该章节的主要事件和情感变化

请按照以下格式输出：

《$title》

【总体梗概】
(这里是整部小说的总体梗概，500字左右)

【章节大纲】
第1章：章节标题
章节内容概述，包含该章节的主要事件、人物互动和情感变化。标明该章节使用的期待感类型。

第2章：章节标题
章节内容概述，包含该章节的主要事件、人物互动和情感变化。标明该章节使用的期待感类型。

...以此类推，直到第${totalChapters}章
''';
  }
} 