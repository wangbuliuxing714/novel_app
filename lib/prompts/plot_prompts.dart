class PlotPrompts {
  static const String outlineTemplate = '''请根据以下要求制定一个详细的小说大纲：

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
   - 圆满结局''';

  static const String chapterTemplate = '''请根据以下要求写作本章节：

章节信息：
标题：{chapter_title}
序号：第{chapter_number}章
字数要求：2000-3000字

上下文信息：
{context}

本章重点：
{focus_points}

爽点设计要求：
1. 每章必须包含至少2个爽点情节
2. 爽点类型可以是：
   - 装逼打脸：碾压对手、以弱胜强
   - 实力展示：秀操作、展示神技
   - 机缘造化：获得奇遇、突破瓶颈
   - 横扫全场：力压群雄、技惊四座
   - 装逼打脸：打脸反派、打脸装逼
3. 爽点设计原则：
   - 前有铺垫，后有回应
   - 循序渐进，层层递进
   - 高潮迭起，扣人心弦
   - 合情合理，不显刻意

写作要求：
1. 保持与前文的连贯性
2. 突出本章重点内容
3. 适当设置悬念
4. 为后续情节做铺垫
5. 注意细节描写
6. 把控节奏和爽点
7. 每章结尾要埋下下一章的期待点''';

  static String generateOutlinePrompt({
    required String title,
    required String genre,
    required String theme,
    required String targetReaders,
  }) {
    return outlineTemplate
        .replaceAll('{title}', title)
        .replaceAll('{genre}', genre)
        .replaceAll('{theme}', theme)
        .replaceAll('{target_readers}', targetReaders);
  }

  static String generateChapterPrompt({
    required String chapterTitle,
    required int chapterNumber,
    required String context,
    required String focusPoints,
  }) {
    return chapterTemplate
        .replaceAll('{chapter_title}', chapterTitle)
        .replaceAll('{chapter_number}', chapterNumber.toString())
        .replaceAll('{context}', context)
        .replaceAll('{focus_points}', focusPoints);
  }
} 