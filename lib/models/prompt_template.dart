import 'package:get/get.dart';

class PromptTemplate {
  final String id;
  final String name;
  final String template;
  final String description;
  final String category;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.template,
    required this.description,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'template': template,
    'description': description,
    'category': category,
  };

  factory PromptTemplate.fromJson(Map<String, dynamic> json) => PromptTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    template: json['template'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
  );
}

class PromptManager extends GetxController {
  static PromptManager get to => Get.find();

  final systemPrompts = <PromptTemplate>[].obs;
  final genrePrompts = <PromptTemplate>[].obs;
  final plotPrompts = <PromptTemplate>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultPrompts();
  }

  void _loadDefaultPrompts() {
    // 系统提示词
    systemPrompts.addAll([
      const PromptTemplate(
        id: 'outline_writer',
        name: '大纲生成器',
        template: '''你是一个专业的小说大纲策划师。你需要根据用户提供的标题、类型、主题和目标读者群体，设计一个引人入胜的故事大纲。
请确保：
1. 设计合理的故事结构和情节发展
2. 创造有特点的角色
3. 设置吸引人的冲突
4. 埋下伏笔，为后续发展做准备
5. 符合特定类型的写作特点''',
        description: '用于生成小说大纲的系统提示词',
        category: 'system',
      ),
      const PromptTemplate(
        id: 'chapter_writer',
        name: '章节生成器',
        template: '''你是一个专业的小说写手。你需要根据提供的上下文信息和重点要求，写出一个精彩的章节。
请确保：
1. 情节连贯，符合整体故事发展
2. 人物性格表现一致
3. 场景描写生动形象
4. 对话自然流畅
5. 保持合适的节奏感''',
        description: '用于生成小说章节的系统提示词',
        category: 'system',
      ),
    ]);

    // 类型提示词
    genrePrompts.addAll([
      const PromptTemplate(
        id: 'fantasy',
        name: '玄幻',
        template: '''玄幻小说特点：
1. 构建独特的修炼体系
2. 设计丰富的法术和功法
3. 创造奇特的天材地宝
4. 安排各种势力之间的争斗
5. 展现主角的成长历程''',
        description: '玄幻类型的写作指导',
        category: 'genre',
      ),
      // 可以添加更多类型的提示词
    ]);

    // 情节提示词
    plotPrompts.addAll([
      const PromptTemplate(
        id: 'outline_prompt',
        name: '大纲生成提示',
        template: '''请为一部题为"{{title}}"的{{genre}}小说创作大纲。
主题：{{theme}}
目标读者：{{targetReaders}}

要求：
1. 设计合理的故事结构
2. 创造有特点的角色
3. 设置吸引人的冲突
4. 符合{{genre}}类型特点
5. 考虑目标读者群体的阅读偏好''',
        description: '用于生成大纲的提示模板',
        category: 'plot',
      ),
      // 可以添加更多情节提示词
    ]);
  }

  void updatePrompt(PromptTemplate newPrompt) {
    switch (newPrompt.category) {
      case 'system':
        final index = systemPrompts.indexWhere((p) => p.id == newPrompt.id);
        if (index != -1) {
          systemPrompts[index] = newPrompt;
        }
        break;
      case 'genre':
        final index = genrePrompts.indexWhere((p) => p.id == newPrompt.id);
        if (index != -1) {
          genrePrompts[index] = newPrompt;
        }
        break;
      case 'plot':
        final index = plotPrompts.indexWhere((p) => p.id == newPrompt.id);
        if (index != -1) {
          plotPrompts[index] = newPrompt;
        }
        break;
    }
  }

  PromptTemplate? getPromptById(String id) {
    return systemPrompts.firstWhereOrNull((p) => p.id == id) ??
           genrePrompts.firstWhereOrNull((p) => p.id == id) ??
           plotPrompts.firstWhereOrNull((p) => p.id == id);
  }
} 