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
  
  // 添加缺少的状态变量
  final RxBool _isReviewing = false.obs;
  final RxString _reviewStatus = ''.obs;

  ContentReviewService(this._aiService, this._apiConfig, this._cacheService);
  
  // 添加状态更新方法
  void _updateStatus(String status) {
    _reviewStatus.value = status;
    print('内容审查状态: $status');
  }

  Future<String> reviewContent({
    required String content,
    required String style,
    required AIModel model,
    String? userRequirements,
  }) async {
    try {
      _isReviewing.value = true;
      _updateStatus('正在审查内容...');

      final systemPrompt = '''你是一位专业的文学编辑，需要对以下内容进行深度审查和润色。请注意：

1. 内容质量：
   - 删除所有重复的段落和相似的描写
   - 确保每个段落都包含新的信息
   - 优化段落之间的逻辑连接
   - 增强内容的生动性和细节描写

2. 语言风格：
   - 按照"$style"的风格要求进行调整
   - 保持语言的一致性
   - 提高表达的准确性
   - 增加语言的多样性

3. 情节发展：
   - 确保情节的连贯性
   - 优化情节的节奏感
   - 增强冲突和转折
   - 完善故事的起承转合

4. 人物塑造：
   - 丰富人物的性格特点
   - 增加人物的心理描写
   - 优化人物对话的真实感
   - 强化人物形象的立体感

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
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 7500,
        temperature: 0.7,
      )) {
        buffer.write(chunk);
      }

      final reviewedContent = buffer.toString();
      
      // 检查审查后的内容是否仍有重复
      if (_cacheService.isContentDuplicate(reviewedContent, [])) {
        _updateStatus('检测到重复内容，进行第二轮审查...');
        
        // 如果仍有重复，进行第二轮审查，使用更强的去重提示
        final secondRoundPrompt = '''请对以下内容进行更严格的去重处理。要求：
1. 彻底删除所有重复或相似的段落
2. 重写任何相似度高的内容
3. 确保每个段落都是独特的
4. 保持故事的连贯性和完整性

内容：
$reviewedContent''';

        final secondBuffer = StringBuffer();
        await for (final chunk in _aiService.generateTextStream(
          systemPrompt: '''你是一位专业的文学编辑，专门处理文本中的重复内容问题。
你的任务是彻底删除所有重复的段落，并确保每个段落都是独特的。''',
          userPrompt: secondRoundPrompt,
          maxTokens: 7500,
          temperature: 0.8,
        )) {
          secondBuffer.write(chunk);
        }
        
        return secondBuffer.toString();
      }

      // 缓存成功的写作模式
      if (reviewedContent.length >= 3000) {
        _cacheService.cacheSuccessfulPattern(style);
      }

      return reviewedContent;
    } catch (e) {
      _updateStatus('内容审查失败: $e');
      return '内容审查过程中发生错误: $e';
    } finally {
      _isReviewing.value = false;
    }
  }

  Future<List<String>> reviewMultipleChapters({
    required List<String> contents,
    required String style,
    required AIModel model,
    String? userRequirements,
  }) async {
    try {
      _isReviewing.value = true;
      _updateStatus('正在审查多个章节...');
      
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
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 7500,
        temperature: 0.7,
      )) {
        buffer.write(chunk);
      }

      // 解析返回的内容，分割成多个章节
      return _splitReviewedContent(buffer.toString());
    } catch (e) {
      _updateStatus('多章节审查失败: $e');
      return ['多章节审查过程中发生错误: $e'];
    } finally {
      _isReviewing.value = false;
    }
  }

  List<String> _splitReviewedContent(String content) {
    return content.split('=== 章节分隔符 ===')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
} 