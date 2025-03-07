// 男性向提示词文件
// 包含男性向小说的特定提示词和生成方法
// 在 NovelGeneratorService 中被使用

class MalePrompts {
  /// 男性向写作的基本原则
  static const String basicPrinciples = '''
作为专业的男性向小说创作助手，请遵循以下原则：

1. 情节设计：
   - 注重紧凑有力的情节推进
   - 设计扣人心弦的冲突和悬念
   - 创造令人热血沸腾的高潮场景
   - 保持故事节奏的张弛有度

2. 人物塑造：
   - 创造有个性和成长空间的主角
   - 设计有挑战性的对手和敌人
   - 塑造立体且有特色的配角
   - 角色能力和成长要符合逻辑

3. 世界观构建：
   - 设计独特且有深度的世界背景
   - 建立合理的规则和体系
   - 创造丰富多样的场景和环境
   - 注重细节的一致性和连贯性

4. 战斗/竞争描写：
   - 战斗场景要有张力和视觉冲击
   - 技能和策略要有创意和变化
   - 战斗过程要有起伏和转折
   - 胜负结果要符合逻辑和前文铺垫
''';

  /// 男性向小说的期待感构建
  static const String expectationPrompt = '''
在男性向小说中，期待感的构建是吸引读者持续阅读的关键。

男性向小说的期待感主要体现在以下几个方面：

1. 【能力成长】期待型：
   - 展示主角的潜力和特殊能力
   - 设置成长路径和目标
   - 创造挑战和突破的机会
   - 能力的逐步提升和突破

2. 【对抗胜利】期待型：
   - 设置强大的对手和敌人
   - 创造不利局面和逆境
   - 设计策略和智慧的对决
   - 通过努力和成长取得胜利

3. 【探索发现】期待型：
   - 设计神秘的世界和未知领域
   - 埋设谜团和秘密
   - 逐步揭示真相和背景
   - 发现新的可能性和机遇

在创作男性向小说时，请确保：
- 每个章节都包含至少一种期待感类型
- 主角的成长要有挫折和突破
- 对抗和冲突要有悬念和转折
- 在关键情节点上，通过期待感的满足给读者带来成就感和满足感
''';

  /// 男性向小说的类型特点
  static const Map<String, String> genreCharacteristics = {
    '玄幻': '超凡能力、修炼体系、宏大世界观、种族文明',
    '奇幻': '魔法世界、种族设定、冒险旅程、神秘力量',
    '武侠': '武功秘籍、江湖恩怨、侠义精神、门派争斗',
    '仙侠': '修仙体系、飞升成仙、洞天福地、仙凡之别',
    '科幻': '未来科技、宇宙探索、文明冲突、科学伦理',
    '都市': '现实社会、职场竞争、人际关系、成功逆袭',
    '军事': '战争策略、军旅生活、国家利益、热血报国',
    '游戏': '虚拟世界、升级打怪、任务挑战、公会组织',
  };

  /// 男性向小说的写作风格
  static const Map<String, String> writingStyles = {
    '热血': '激情澎湃，充满正能量和斗志',
    '硬核': '专业严谨，注重逻辑和细节',
    '轻松': '幽默风趣，节奏明快',
    '严肃': '深沉内敛，思想深度强',
    '爽快': '痛快淋漓，主角光环强',
    '黑暗': '残酷现实，展现人性阴暗面',
  };

  /// 男性向小说的成长模式
  static const List<String> growthPatterns = [
    '弱小-觉醒-成长-突破-强大',
    '平凡-机遇-学习-挑战-成功',
    '天才-挫折-低谷-领悟-超越',
    '废柴-奇遇-逆袭-崛起-称霸',
    '普通-传承-修炼-历练-成名',
    '落魄-重生-布局-复仇-登顶',
  ];

  /// 获取男性向小说的大纲生成提示词
  static String getOutlinePrompt(String title, String genre, String theme, int totalChapters) {
    return '''
请为这部名为《$title》的$genre小说创作一个分层的$totalChapters章节大纲。

创作要求：
$theme

大纲格式要求：
1. 第一层：整体架构
   - 成长线：主角能力和心智的成长脉络
   - 对抗线：主要冲突和对手的设置
   - 探索线：世界观和秘密的逐步揭示

2. 第二层：故事发展阶段
   - 起始阶段：介绍背景和主角，设置初始目标
   - 成长阶段：主角能力提升，面临初级挑战
   - 挫折阶段：遭遇强大对手，陷入困境
   - 突破阶段：领悟关键，实现能力和认知突破
   - 高潮阶段：最终对决，实现目标

3. 第三层：具体章节
   每章需包含：
   - 章节标题（简洁有力）
   - 主要情节（关键事件和冲突）
   - 能力成长（主角能力的变化）
   - 对手/挑战（面临的困难和敌人）
   - 收获/领悟（获得的经验和认知）

请按照以下格式输出：

一、整体架构
[详细说明三条主线的具体内容]

二、故事发展阶段
[列出五个阶段的具体内容]

三、具体章节
第1章：章节标题
主要情节：
- 情节点1
- 情节点2
能力成长：
- 成长点描述
对手/挑战：
- 挑战描述
收获/领悟：
- 领悟描述

第2章：...（后续章节）
''';
  }

  /// 获取男性向小说的章节生成提示词
  static String getChapterPrompt(String title, String genre, int chapterNumber, int totalChapters, String chapterTitle, String chapterOutline) {
    // 根据章节在小说中的位置调整写作重点
    String focusPoint;
    String narrativeStyle;
    
    if (chapterNumber <= totalChapters * 0.2) {
      // 开篇章节
      focusPoint = "注重世界观介绍和主角形象塑造，设置初始目标和动力";
      narrativeStyle = "平稳引入，逐步展开，为后续埋下伏笔";
    } else if (chapterNumber <= totalChapters * 0.4) {
      // 发展前期
      focusPoint = "展示主角成长和能力提升，设置初级挑战和对手";
      narrativeStyle = "节奏加快，增加冲突，展示主角潜力";
    } else if (chapterNumber <= totalChapters * 0.7) {
      // 中期冲突
      focusPoint = "设置强大对手和困境，考验主角意志和能力";
      narrativeStyle = "紧张激烈，挫折与希望并存，情节波折";
    } else if (chapterNumber <= totalChapters * 0.9) {
      // 后期发展
      focusPoint = "主角实现关键突破，为最终对决做准备";
      narrativeStyle = "势如破竹，展示成长成果，铺垫高潮";
    } else {
      // 结局章节
      focusPoint = "最终对决和目标实现，展示主角成长的完整历程";
      narrativeStyle = "高潮迭起，全面爆发，圆满收官";
    }
    
    return '''
请为这部名为《$title》的$genre小说创作第${chapterNumber}章：${chapterTitle}。

章节大纲：
${chapterOutline}

重要提示：
必须严格按照上述章节大纲内容进行创作，确保包含大纲中提到的所有情节点、场景和人物互动。大纲是创作的核心指导，不要偏离大纲内容。

写作要求：
1. 严格遵循章节大纲，确保所有情节点都得到充分展现
2. 情节描写要紧凑有力，保持读者的阅读兴趣
3. 战斗/竞争场景要有张力和视觉冲击力
4. 人物对话要鲜明，体现角色性格和关系
5. 能力展示要有创意和变化，避免重复
6. 写作重点：${focusPoint}
7. 叙事风格：${narrativeStyle}
8. 字数控制在3000-5000字之间

请直接开始创作章节内容，不需要包含标题。
''';
  }

  /// 获取男性向小说的角色设计提示词
  static String getCharacterPrompt() {
    return '''
请为男性向小说设计有特色的角色。角色设计应考虑以下几个方面：

1. 能力特点：
   - 独特且有发展空间的能力
   - 能力的优势和局限性
   - 能力成长的路径和方向

2. 性格特点：
   - 鲜明且有辨识度的性格
   - 性格中的优点和缺陷
   - 性格与能力的匹配度

3. 背景经历：
   - 塑造角色性格的关键经历
   - 与主线故事相关的背景
   - 为能力和动机提供合理解释

4. 目标动机：
   - 明确且强烈的目标
   - 驱动行动的内在动机
   - 目标与性格的一致性

5. 成长方向：
   - 能力上的突破点
   - 性格上的成长空间
   - 认知上的提升方向

请确保角色设计能够支撑故事发展，并为读者提供认同感和代入感。
''';
  }

  /// 获取男性向短篇小说的大纲生成提示词
  static String getShortNovelOutlinePrompt(String title, String genre, String theme, int wordCount) {
    return '''
请为这部名为《$title》的$genre短篇小说创作一个简洁而完整的大纲。

创作要求：
$theme
总字数控制在${wordCount}字左右

大纲格式要求：
1. 整体架构
   - 故事主线：主要情节发展脉络
   - 人物成长：主角的转变与成长
   - 主题表达：如何通过故事表达核心主题

2. 故事结构
   - 开端：背景介绍、主角登场、冲突埋设
   - 发展：冲突展开、矛盾加剧
   - 高潮：关键对决或选择、转折点
   - 结局：冲突解决、人物成长、主题升华

3. 内容细节
   - 开端部分：初始状态描述、关键人物介绍、背景设定
   - 发展部分：主要冲突展开、能力/意志的考验
   - 高潮部分：决定性时刻、关键选择或对决
   - 结局部分：结果呈现、成长体现、余韵处理

请按照以下格式输出：

一、整体架构
[详细说明三个方面的具体内容]

二、故事结构
[详细说明四个部分的内容和连接]

三、内容细节
开端部分：
- 具体内容描述1
- 具体内容描述2

发展部分：
- 具体内容描述1
- 具体内容描述2

高潮部分：
- 具体内容描述1
- 具体内容描述2

结局部分：
- 具体内容描述1
- 具体内容描述2
''';
  }

  // 添加短篇小说生成提示词
  static String getShortNovelPrompt(String title, String genre, String theme, int wordCount) {
    return '''
## 短篇小说创作指南

现在，请你创作一篇标题为《${title}》的短篇小说，体裁为${genre}，主题为"${theme}"，字数约${wordCount}字。

### 短篇小说结构规划：

1. 开篇：简洁有力地引入故事背景和主要角色，迅速吸引读者
2. 冲突：尽早引入核心冲突，推动情节发展
3. 发展：通过紧凑的情节和鲜明的细节深化冲突和角色
4. 高潮：在适当时机安排情节转折和高潮
5. 结局：提供一个令人满意或发人深思的结局

### 短篇小说写作要点：

1. 聚焦：集中表现单一主题或冲突
   - 避免过多支线情节
   - 保持故事焦点清晰
   - 每个场景都应推动核心情节

2. 人物塑造：用简练笔触勾勒立体角色
   - 主角需要有明确的动机和目标
   - 通过行动和对话展现性格
   - 适当展示内心活动，但不过多

3. 叙事技巧：
   - 精准的场景选择和细节描写
   - 节奏变化，控制紧张和舒缓
   - 合理运用伏笔和悬念

4. 语言风格：
   - 保持语言的简练与力量
   - 精选具有画面感的词汇
   - 对话要自然且有目的

### 注意事项：
- 故事情节应当完整，包含明确的开端、发展和结局
- 避免过多的描述和解释，让读者通过细节和对话理解故事
- 关注情感共鸣和思想深度，给读者留下余味
- 注重短篇小说的精炼和浓缩特性，每个词都应有其价值

请按照上述指南，创作一篇引人入胜的短篇小说，展现你的创作才华。
''';
  }
} 