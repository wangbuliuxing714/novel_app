import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/services/cache_service.dart';

class ContentReviewService extends GetxService {
  final AIService _aiService;
  final ApiConfigController _apiConfig;
  final CacheService _cacheService;

  ContentReviewService(this._aiService, this._apiConfig, this._cacheService);

  Future<String> reviewContent({
    required String content,
    required String style,
    required AIModel model,
  }) async {
    final systemPrompt = '''【重要提示】
在开始审查和优化内容之前：
1. 请仔细阅读并完全理解所有审查要求
2. 确保理解每一条规则和用户的具体要求
3. 在审查过程中始终保持警惕
4. 如有疑问，请按最严格的标准执行审查

【审查原则】
你是一位严谨的文学编辑，需要遵循以下原则：

1. 内容质量控制（最高优先级）：
   - 严格检查并删除任何重复的段落
   - 确保每个段落都包含独特的信息
   - 避免相似句式的重复使用
   - 保持场景描写的独特性
   - 增强段落之间的逻辑连贯性

2. 重复内容检查（最高优先级）：
   - 严格检查并删除任何重复的段落
   - 确保每个段落都包含新的信息
   - 避免使用相似的句式和描写方式
   - 检查并优化相似场景的描写
   - 保持每个段落的独特性

3. 内容质量控制：
   - 确保每个段落都有实质内容
   - 删除冗余和无意义的过渡段落
   - 优化段落之间的逻辑连接
   - 增强场景描写的生动性
   - 提升人物刻画的立体感

4. 写作风格优化：
   - 根据指定风格调整表达方式
   - 保持文风的一致性
   - 增强语言的表现力
   - 优化修辞手法的运用

5. 结构完整性：
   - 检查段落之间的衔接
   - 确保情节发展的连贯性
   - 优化场景转换的自然度
   - 保持人物行为的合理性

6. 细节增强：
   - 补充必要的环境描写
   - 丰富人物的心理活动
   - 完善情节细节
   - 增加感官描写的丰富度

请对内容进行深入审查，确保没有重复段落，并按照要求进行润色。''';

    final userPrompt = '''请对以下内容进行深度审查和润色。重点关注：
1. 删除所有重复的段落和相似的描写
2. 确保每个段落都包含新的信息
3. 优化段落之间的逻辑连接
4. 按照"$style"的风格要求进行调整
5. 增强内容的生动性和细节描写

以下是需要审查的内容：
$content''';

    final buffer = StringBuffer();
    
    await for (final chunk in _aiService.generateTextStream(
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 8100,
      temperature: 0.7,
    )) {
      buffer.write(chunk);
    }

    final reviewedContent = buffer.toString();
    
    // 检查审查后的内容是否仍有重复
    if (_cacheService.isContentDuplicate(reviewedContent, [])) {
      // 如果仍有重复，进行第二轮审查
      return await reviewContent(
        content: reviewedContent,
        style: style,
        model: model,
      );
    }

    // 缓存成功的写作模式
    if (reviewedContent.length >= 3000) {
      _cacheService.cacheSuccessfulPattern(style);
    }

    return reviewedContent;
  }

  Future<List<String>> reviewMultipleChapters({
    required List<String> contents,
    required String style,
    required AIModel model,
    String? userRequirements,
  }) async {
    final systemPrompt = '''你是一位专业的文学编辑，需要对多个连续章节进行整体校对和润色。请注意：

1. 章节间的连贯性：
   - 情节过渡是否自然
   - 人物发展是否连贯
   - 伏笔和呼应是否合理
   - 节奏把控是否适当

2. 整体风格统一：
   - 保持叙事风格一致
   - 统一人物描写方式
   - 场景描写风格统一
   - 对话风格保持一致

3. 逻辑优化：
   - 调整不合理的情节
   - 完善因果关系
   - 优化时间线安排
   - 加强情节关联

4. 艺术性提升：
   - 统一文学风格
   - 优化语言表达
   - 加强意境营造
   - 提升整体质感

请在保持故事核心的基础上，提升整体的艺术性和连贯性。''';

    String userPrompt = '''请对以下连续章节进行整体校对和润色：

【章节内容】
${contents.join('\n\n=== 章节分隔符 ===\n\n')}

【写作风格】
$style

${userRequirements != null ? '\n【用户特殊要求】\n$userRequirements' : ''}

【校对要求】
1. 确保章节之间的连贯性
2. 优化情节过渡
3. 统一写作风格
4. 提升整体艺术性
5. 保持人物塑造的一致性''';

    final buffer = StringBuffer();
    
    await for (final chunk in _aiService.generateTextStream(
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 8000,
      temperature: 0.7,
    )) {
      buffer.write(chunk);
    }

    // 解析返回的内容，分割成多个章节
    return _splitReviewedContent(buffer.toString());
  }

  List<String> _splitReviewedContent(String content) {
    return content.split('=== 章节分隔符 ===')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
} 