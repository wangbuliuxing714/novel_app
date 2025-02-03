import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:novel_app/controllers/api_config_controller.dart';

class DeepseekService {
  final apiConfigController = Get.find<ApiConfigController>();

  // 计算中文字数
  int _calculateWordCount(String text) {
    return text.replaceAll(RegExp(r'\s'), '').length;
  }

  // 根据API限制，max_tokens的范围是[1, 8192]
  // 我们需要分多次请求来生成更长的内容
  int _getMaxTokens(String length) {
    switch (length) {
      case '短篇':
        return 4000;  // 预期生成约2000字
      case '中篇':
        return 6000;  // 预期生成约3000字
      case '长篇':
        return 8000;  // 预期生成约4000字
      default:
        return 4000;
    }
  }

  String _getSystemPrompt(String style) {
    return '''你是一位经验丰富的网络小说作家，擅长创作各类爽文网文。作为专业的爽文写手，你需要遵循以下要求：

1. 专业性增强（最重要）：
   - 根据不同场景准确使用专业术语和行话
   - 战斗场景：具体的招式名称、力道参数（如："一记迅猛的直拳，力道达到2.3吨"）
   - 修炼场景：详细的境界划分、具体的能量数值（如："灵力浓度达到367ppm"）
   - 商战场景：准确的金融术语、具体的数据指标（如："季度ROI达到37.8%"）
   - 科技场景：精确的技术参数、具体的型号规格（如："量子计算机的相干时间达到97微秒"）

2. 感官沉浸（重要）：
   - 视觉：不仅写"看到"，还要有光影、色彩、动态的细节
   - 听觉：环境音、对话音、心跳声等声音的层次感
   - 触觉：温度、质地、压力等触感的具体描述
   - 嗅觉：空气中的气味变化、情绪带来的微妙气息
   - 味觉：当场景涉及饮食，详细描写味道层次
   - 多感官联动：在关键场景同时调动3种以上感官

3. 叙事纵深：
   - 时间线交织：现在、回忆、预示三条线并行
   - 空间层次：近景、中景、远景的场景切换
   - 视角转换：适时切换第一人称、第三人称、全知视角
   - 因果链条：每个情节都要埋下后续发展的伏笔
   - 情感递进：通过细节暗示情感变化，避免直白表达

4. 写作技巧：
   - 场景细节要生动形象
   - 打斗场面要有张力
   - 对话要简洁有力
   - 保持节奏紧凑
   - 增加诙谐元素

5. 注意事项：
   - 保持人物性格一致性
   - 注意前后文的连贯性
   - 避免重复性内容
   - 直接返回小说内容，不需要解释说明
   - 符合$style风格特点''';
  }

  Future<Map<String, dynamic>> generateNovel({
    required String title,
    required String prompt,
    required String length,
    required String style,
  }) async {
    final apiKey = apiConfigController.apiKey.value;
    final apiUrl = apiConfigController.apiUrl.value;

    if (apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }

    // 计算需要生成的次数
    int targetLength = length == '短篇' ? 3000 : (length == '中篇' ? 6000 : 12000);
    int parts = (targetLength / 2000).ceil(); // 每次生成约2000字
    List<String> contents = [];

    for (int i = 0; i < parts; i++) {
      final response = await http.post(
        Uri.parse('$apiUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-reasoner',
          'messages': [
            {
              'role': 'system',
              'content': _getSystemPrompt(style),
            },
            if (i > 0 && contents.isNotEmpty) {
              'role': 'assistant',
              'content': contents.last,
            },
            {
              'role': 'user',
              'content': '''请${i == 0 ? '创作' : '继续'}一篇$style风格的爽文：
标题：$title
要求：
1. 风格：$style
2. ${i == 0 ? '开始创作故事的开端部分' : '继续发展故事情节'}
3. 具体要求：$prompt
4. 请直接开始创作，不需要解释和说明。'''
            }
          ],
          'temperature': 0.8,
          'max_tokens': _getMaxTokens(length),
        }),
        encoding: utf8,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        contents.add(content);
      } else {
        throw Exception('生成失败：${utf8.decode(response.bodyBytes)}');
      }

      // 如果不是最后一部分，等待一下再继续请求
      if (i < parts - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // 合并所有内容并计算字数
    final fullContent = contents.join('\n\n');
    final wordCount = _calculateWordCount(fullContent);

    return {
      'content': fullContent,
      'word_count': wordCount,
    };
  }
} 