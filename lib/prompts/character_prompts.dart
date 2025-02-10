// 角色相关提示词文件
// 包含角色类型和角色卡片的提示词
// 在 CharacterTypeService 和 CharacterCardService 中使用

class CharacterPrompts {
  /// 获取角色类型的写作要求
  static String getCharacterTypeRequirements(String type) {
    switch (type) {
      case '主角':
        return _protagonistRequirements;
      case '女主角':
        return _heroineRequirements;
      case '反派':
        return _antagonistRequirements;
      case '配角':
        return _supportingRoleRequirements;
      default:
        return _generalCharacterRequirements;
    }
  }

  /// 主角的写作要求
  static const String _protagonistRequirements = '''
1. 性格塑造：
   - 鲜明的个性特征
   - 独特的性格魅力
   - 成长的可能性
   - 内心的矛盾与挣扎

2. 能力设定：
   - 核心竞争力
   - 特殊才能
   - 成长空间
   - 能力限制

3. 背景设定：
   - 成长经历
   - 家庭背景
   - 重要人际关系
   - 关键生活事件

4. 行为特征：
   - 处事方式
   - 说话风格
   - 习惯动作
   - 价值观念
''';

  /// 女主角的写作要求
  static const String _heroineRequirements = '''
1. 性格特点：
   - 独立的个性
   - 感性的一面
   - 成长的轨迹
   - 价值观念

2. 能力特长：
   - 专业技能
   - 特殊才华
   - 个人魅力
   - 发展潜力

3. 背景设定：
   - 家庭环境
   - 成长经历
   - 重要关系
   - 人生目标

4. 外在特征：
   - 形象特点
   - 穿着风格
   - 举止气质
   - 表达方式
''';

  /// 反派的写作要求
  static const String _antagonistRequirements = '''
1. 性格特征：
   - 复杂的内心世界
   - 行为动机
   - 价值观念
   - 性格缺陷

2. 能力设定：
   - 核心实力
   - 特殊手段
   - 资源背景
   - 弱点限制

3. 背景故事：
   - 成为反派的原因
   - 重要经历
   - 关键转折点
   - 与主角的关系

4. 行为模式：
   - 处事风格
   - 说话特点
   - 标志性动作
   - 决策方式
''';

  /// 配角的写作要求
  static const String _supportingRoleRequirements = '''
1. 角色定位：
   - 在故事中的作用
   - 与主角的关系
   - 情节推动作用
   - 主题表达作用

2. 性格特点：
   - 鲜明的个性
   - 独特的魅力
   - 行为特征
   - 性格缺陷

3. 背景设定：
   - 身份背景
   - 重要经历
   - 关键关系
   - 个人目标

4. 发展轨迹：
   - 成长变化
   - 情感发展
   - 命运走向
   - 结局安排
''';

  /// 通用角色要求
  static const String _generalCharacterRequirements = '''
1. 基本设定：
   - 身份背景
   - 性格特点
   - 能力特长
   - 外在特征

2. 行为特征：
   - 处事方式
   - 说话风格
   - 行为习惯
   - 价值观念

3. 关系网络：
   - 重要关系
   - 社交圈子
   - 情感联系
   - 对立关系

4. 发展轨迹：
   - 成长变化
   - 情感发展
   - 目标追求
   - 结局安排
''';

  /// 获取角色卡片的生成提示词
  static String getCharacterCardPrompt(Map<String, String?> characterInfo) => '''
请根据以下信息，生成一个完整的角色设定：

基本信息：
${characterInfo['name'] != null ? '姓名：${characterInfo['name']}\n' : ''}
${characterInfo['gender'] != null ? '性别：${characterInfo['gender']}\n' : ''}
${characterInfo['age'] != null ? '年龄：${characterInfo['age']}\n' : ''}
${characterInfo['race'] != null ? '种族：${characterInfo['race']}\n' : ''}

外貌特征：
${characterInfo['bodyDescription'] != null ? '体型：${characterInfo['bodyDescription']}\n' : ''}
${characterInfo['faceFeatures'] != null ? '面部特征：${characterInfo['faceFeatures']}\n' : ''}
${characterInfo['clothingStyle'] != null ? '服装风格：${characterInfo['clothingStyle']}\n' : ''}
${characterInfo['accessories'] != null ? '标志性配饰：${characterInfo['accessories']}\n' : ''}

性格特征：
${characterInfo['personalityTraits'] != null ? '主要性格：${characterInfo['personalityTraits']}\n' : ''}
${characterInfo['personalityComplexity'] != null ? '性格复杂性：${characterInfo['personalityComplexity']}\n' : ''}
${characterInfo['personalityFormation'] != null ? '性格形成原因：${characterInfo['personalityFormation']}\n' : ''}

背景故事：
${characterInfo['background'] != null ? '成长背景：${characterInfo['background']}\n' : ''}
${characterInfo['lifeExperiences'] != null ? '人生经历：${characterInfo['lifeExperiences']}\n' : ''}
${characterInfo['pastEvents'] != null ? '重要事件：${characterInfo['pastEvents']}\n' : ''}

目标和动机：
${characterInfo['shortTermGoals'] != null ? '短期目标：${characterInfo['shortTermGoals']}\n' : ''}
${characterInfo['longTermGoals'] != null ? '长期目标：${characterInfo['longTermGoals']}\n' : ''}
${characterInfo['motivation'] != null ? '行为动机：${characterInfo['motivation']}\n' : ''}

能力和技能：
${characterInfo['specialAbilities'] != null ? '特殊能力：${characterInfo['specialAbilities']}\n' : ''}
${characterInfo['normalSkills'] != null ? '普通技能：${characterInfo['normalSkills']}\n' : ''}

人际关系：
${characterInfo['familyRelations'] != null ? '家庭关系：${characterInfo['familyRelations']}\n' : ''}
${characterInfo['friendships'] != null ? '朋友关系：${characterInfo['friendships']}\n' : ''}
${characterInfo['enemies'] != null ? '敌对关系：${characterInfo['enemies']}\n' : ''}
${characterInfo['loveInterests'] != null ? '情感关系：${characterInfo['loveInterests']}\n' : ''}
''';

  /// 检查角色卡片完整性
  static bool validateCharacterCard(Map<String, String?> characterInfo) {
    // 必填字段
    final requiredFields = ['name', 'gender', 'age', 'personalityTraits'];
    
    // 检查必填字段
    for (var field in requiredFields) {
      if (characterInfo[field]?.isEmpty ?? true) {
        return false;
      }
    }
    
    // 检查是否至少填写了一个特征描述
    final hasFeatures = (characterInfo['bodyDescription']?.isNotEmpty ?? false) ||
        (characterInfo['faceFeatures']?.isNotEmpty ?? false) ||
        (characterInfo['clothingStyle']?.isNotEmpty ?? false);
    
    // 检查是否至少填写了一个背景信息
    final hasBackground = (characterInfo['background']?.isNotEmpty ?? false) ||
        (characterInfo['lifeExperiences']?.isNotEmpty ?? false) ||
        (characterInfo['pastEvents']?.isNotEmpty ?? false);
    
    return hasFeatures && hasBackground;
  }
} 