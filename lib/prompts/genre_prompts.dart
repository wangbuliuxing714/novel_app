// 类型提示词文件
// 包含各种小说类型的特定要求和提示词
// 在 GenreController 和 NovelGeneratorService 中使用

class NovelGenre {
  final String name;
  final String description;
  final String prompt;

  const NovelGenre({
    required this.name,
    required this.description,
    required this.prompt,
  });
}

class GenreCategory {
  final String name;
  final List<NovelGenre> genres;

  const GenreCategory({
    required this.name,
    required this.genres,
  });
}

class GenrePrompts {
  static const List<GenreCategory> categories = [
    GenreCategory(
      name: '都市现代',
      genres: [
        NovelGenre(
          name: '都市异能',
          description: '都市背景下的超能力故事',
          prompt: '都市异能：重生、系统流、赘婿、神豪等元素',
        ),
        NovelGenre(
          name: '娱乐圈',
          description: '演艺圈发展故事',
          prompt: '娱乐圈：星探、试镜、爆红、黑料等元素',
        ),
        NovelGenre(
          name: '职场商战',
          description: '职场或商业竞争故事',
          prompt: '职场商战：升职加薪、商业谈判、公司运营等元素',
        ),
        NovelGenre(
          name: '亿万富翁',
          description: '富豪人生故事',
          prompt: '亿万富翁：财富积累、商业帝国、豪门生活等元素',
        ),
      ],
    ),
    GenreCategory(
      name: '玄幻修仙',
      genres: [
        NovelGenre(
          name: '玄幻修仙',
          description: '修真问道的故事',
          prompt: '玄幻修仙：修炼体系、宗门势力、天材地宝等元素',
        ),
        NovelGenre(
          name: '重生',
          description: '重获新生的故事',
          prompt: '重生：前世记忆、改变命运、复仇崛起等元素',
        ),
        NovelGenre(
          name: '系统流',
          description: '获得系统的故事',
          prompt: '系统流：金手指、任务奖励、属性面板等元素',
        ),
      ],
    ),
    GenreCategory(
      name: '游戏竞技',
      genres: [
        NovelGenre(
          name: '电竞',
          description: '电子竞技故事',
          prompt: '电竞：职业选手、战队训练、比赛竞技等元素',
        ),
        NovelGenre(
          name: '游戏',
          description: '游戏世界的故事',
          prompt: '游戏：虚拟世界、副本攻略、公会组织等元素',
        ),
        NovelGenre(
          name: '无限流',
          description: '轮回闯关的故事',
          prompt: '无限流：任务世界、轮回闯关、积分兑换等元素',
        ),
      ],
    ),
    GenreCategory(
      name: '科幻未来',
      genres: [
        NovelGenre(
          name: '末世',
          description: '末日求生的故事',
          prompt: '末世：病毒爆发、丧尸横行、废土重建等元素',
        ),
        NovelGenre(
          name: '赛博朋克',
          description: '高科技低生活的故事',
          prompt: '赛博朋克：机械改造、黑客技术、巨型企业等元素',
        ),
        NovelGenre(
          name: '机器人觉醒',
          description: 'AI觉醒的故事',
          prompt: '机器人觉醒：人工智能、机械文明、人机共存等元素',
        ),
      ],
    ),
    GenreCategory(
      name: '古代历史',
      genres: [
        NovelGenre(
          name: '宫斗',
          description: '后宫争斗的故事',
          prompt: '宫斗：后宫争宠、权谋算计、皇权斗争等元素',
        ),
        NovelGenre(
          name: '穿越',
          description: '穿越时空的故事',
          prompt: '穿越：时空穿梭、历史改变、文化冲突等元素',
        ),
        NovelGenre(
          name: '种田',
          description: '农家生活的故事',
          prompt: '种田：农家生活、乡村发展、生活技能等元素',
        ),
        NovelGenre(
          name: '民国',
          description: '民国时期的故事',
          prompt: '民国：乱世生存、谍战情报、革命斗争等元素',
        ),
      ],
    ),
    GenreCategory(
      name: '情感',
      genres: [
        NovelGenre(
          name: '言情',
          description: '纯爱故事',
          prompt: '言情：甜宠恋爱、情感纠葛、浪漫邂逅等元素',
        ),
        NovelGenre(
          name: '虐文',
          description: '虐心故事',
          prompt: '虐文：情感折磨、误会纠葛、痛苦救赎等元素',
        ),
        NovelGenre(
          name: '禁忌之恋',
          description: '禁忌感情故事',
          prompt: '禁忌之恋：身份差距、伦理冲突、命运阻隔等元素',
        ),
        NovelGenre(
          name: '耽美',
          description: '男男感情故事',
          prompt: '耽美：男男情感、相知相守、甜虐交织等元素',
        ),
      ],
    ),
    GenreCategory(
      name: '其他题材',
      genres: [
        NovelGenre(
          name: '灵异',
          description: '灵异故事',
          prompt: '灵异：鬼怪神秘、通灵驱邪、阴阳交界等元素',
        ),
        NovelGenre(
          name: '悬疑',
          description: '悬疑推理故事',
          prompt: '悬疑：案件侦破、推理解谜、心理较量等元素',
        ),
        NovelGenre(
          name: '沙雕',
          description: '搞笑欢乐故事',
          prompt: '沙雕：欢乐搞笑、日常吐槽、轻松愉快等元素',
        ),
        NovelGenre(
          name: '直播',
          description: '直播生活故事',
          prompt: '直播：网络主播、粉丝互动、直播生态等元素',
        ),
      ],
    ),
  ];

  /// 根据小说类型获取提示词
  static String getPromptByGenre(String genre) {
    for (var category in categories) {
      for (var novelGenre in category.genres) {
        if (novelGenre.name == genre) {
          return novelGenre.prompt;
        }
      }
    }
    // 如果找不到对应类型，返回都市异能的提示词作为默认值
    return categories[0].genres[0].prompt;
  }
} 