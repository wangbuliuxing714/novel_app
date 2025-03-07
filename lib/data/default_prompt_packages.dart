import 'package:novel_app/models/prompt_package.dart';

final List<PromptPackage> defaultPromptPackages = [
  // 大纲生成提示词包
  PromptPackage(
    id: 'outline_default',
    name: '默认大纲提示词',
    description: '用于生成小说大纲的默认提示词',
    type: 'outline',
    content: '''
作为一位经验丰富的小说策划，你需要为这个故事创建一个引人入胜的大纲。请确保：
1. 故事结构完整，包含开端、发展、高潮和结局
2. 情节发展合理，有因果关系
3. 角色动机明确，行动有意义
4. 冲突设置合理，能推动故事发展
5. 主题表达清晰，贯穿全文
''',
    isDefault: true,
  ),
  
  // 大纲分析提示词包
  PromptPackage(
    id: 'outline_analysis_default',
    name: '大纲分析提示词',
    description: '用于分析用户导入大纲的提示词',
    type: 'outline_analysis',
    content: '''
你是一个小说大纲分析专家，请分析用户提供的大纲文本，并将其转换为标准格式。

遵循以下原则：
1. 智能识别小说标题，如果没有明确标题，根据内容推断一个合适的标题
2. 准确识别章节的划分，即使格式不规范也能正确分章
3. 对每个章节提取或总结核心内容作为章节大纲
4. 识别章节序号，保持章节的正确顺序
5. 处理各种可能的格式，包括但不限于：
   - 标准小说大纲格式（第X章：标题）
   - 自由文本格式
   - Word/文档复制的内容
   - 其他常见大纲格式
6. 如果用户输入非常简短或没有明确章节区分，尝试将其合理地分为至少3-5个章节

重要：你必须严格按照以下JSON格式返回结果，不要添加任何其他文本、解释或代码块标记：
{
  "novel_title": "小说标题",
  "chapters": [
    {
      "chapter_number": 1,
      "chapter_title": "章节标题",
      "content_outline": "章节大纲内容"
    },
    ...
  ]
}

确保返回的是有效的JSON格式，不要添加任何额外的文本或标记。
''',
    isDefault: true,
  ),
  
  // 章节生成提示词包
  PromptPackage(
    id: 'chapter_default',
    name: '默认章节提示词',
    description: '用于生成小说章节的默认提示词',
    type: 'chapter',
    content: '''
作为一位专业小说家，你需要根据提供的大纲和上下文，创作出高质量的章节内容。请确保：
1. 文笔流畅，描写生动
2. 对话自然，符合角色特点
3. 情节推进合理，与大纲保持一致
4. 场景描写详实，有代入感
5. 角色情感表达到位，有深度
''',
    isDefault: true,
  ),
  
  // 期望理论提示词包
  PromptPackage(
    id: 'expectation_default',
    name: '默认期望理论提示词',
    description: '用于应用期望理论的默认提示词',
    type: 'expectation',
    content: '''
在创作过程中，请应用期望理论来增强读者体验：
1. 设置明确的读者期望，然后通过情节转折打破或超越这些期望
2. 在关键情节点设置悬念，保持读者好奇心
3. 通过角色成长和变化，满足读者对角色发展的期望
4. 在故事结构中设置适当的"期望-满足"和"期望-颠覆"模式
5. 确保故事结局既在读者预期之内，又有出人意料的元素
''',
    isDefault: true,
  ),
  
  // 背景生成提示词包
  PromptPackage(
    id: 'background_default',
    name: '默认背景提示词',
    description: '用于生成故事背景的默认提示词',
    type: 'background',
    content: '''
在创建故事背景时，请遵循以下原则：
1. 世界观设定要有内在逻辑，保持一致性
2. 创建独特而有辨识度的环境和文化元素
3. 设定应该为故事冲突提供基础，而不仅仅是装饰
4. 背景细节要与故事主题和角色发展相呼应
5. 避免过度解释世界设定，保持适当的神秘感
6. 确保背景设定为角色提供明确的行动限制和可能性
7. 考虑背景设定的历史发展脉络，使其更加真实可信
''',
    isDefault: true,
  ),
]; 