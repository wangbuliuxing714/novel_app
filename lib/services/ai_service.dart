import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/controllers/api_config_controller.dart';

enum AIModel {
  deepseek,
  deepseekChat,
  qwen,
  geminiPro,
  geminiFlash,
}

class AIService extends GetxService {
  final ApiConfigController _apiConfig;
  final _client = http.Client();
  final _timeout = const Duration(seconds: 30);
  final _maxRetries = 3;

  AIService(this._apiConfig);

  Stream<String> generateTextStream({
    required AIModel model,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 4000,
    double temperature = 0.8,
  }) async* {
    switch (model) {
      case AIModel.deepseek:
        yield* _streamDeepseek(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
          model: 'deepseek-reasoner',
        );
      case AIModel.deepseekChat:
        yield* _streamDeepseek(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
          model: 'deepseek-chat',
        );
      case AIModel.qwen:
        yield* _streamQwen(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      case AIModel.geminiPro:
        yield* _streamGeminiPro(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
      case AIModel.geminiFlash:
        yield* _streamGeminiFlash(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          maxTokens: maxTokens,
          temperature: temperature,
        );
    }
  }

  Future<http.StreamedResponse> _postWithRetry({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    int retryCount = 0,
  }) async {
    try {
      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = body;

      final response = await _client.send(request).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return response;
      } else if (response.statusCode >= 500 && retryCount < _maxRetries) {
        // 服务器错误，尝试重试
        await Future.delayed(Duration(seconds: 1 << retryCount));
        return _postWithRetry(
          uri: uri,
          headers: headers,
          body: body,
          retryCount: retryCount + 1,
        );
      } else {
        throw Exception('API 请求失败：${response.statusCode}');
      }
    } catch (e) {
      if (retryCount < _maxRetries) {
        // 网络错误，尝试重试
        await Future.delayed(Duration(seconds: 1 << retryCount));
        return _postWithRetry(
          uri: uri,
          headers: headers,
          body: body,
          retryCount: retryCount + 1,
        );
      }
      rethrow;
    }
  }

  Stream<String> _streamDeepseek({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
    required String model,
  }) async* {
    final config = _apiConfig.getModelConfig(
      model == 'deepseek-chat' ? AIModel.deepseekChat : AIModel.deepseek
    );
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 Deepseek API Key');
    }

    try {
      final response = await _postWithRetry(
        uri: Uri.parse('${config.apiUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userPrompt,
            },
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
        }),
      );

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          if (data == '[DONE]') continue;
          
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (e) {
            print('Error parsing chunk: $chunk');
            print('Error: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('Deepseek API error: $e');
      rethrow;
    }
  }

  Stream<String> _streamGeminiPro({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getModelConfig(AIModel.geminiPro);
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 Gemini API Key');
    }

    try {
      final uri = Uri.parse('${config.apiUrl}/models/gemini-pro:streamGenerateContent');
      final request = http.Request('POST', uri);
      
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-goog-api-key': config.apiKey,
      });

      request.body = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$systemPrompt\n\n$userPrompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens,
          'topP': 0.8,
          'topK': 40,
        },
      });

      final response = await _client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('API 请求超时，请重试');
        },
      );
      
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('生成失败：$body');
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        try {
          if (chunk.trim().isEmpty) continue;

          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              if (jsonStr == '[DONE]') continue;

              try {
                final json = jsonDecode(jsonStr);
                if (json['candidates'] != null && json['candidates'].isNotEmpty) {
                  final content = json['candidates'][0]['content'];
                  if (content != null && content['parts'] != null) {
                    final parts = content['parts'] as List;
                    if (parts.isNotEmpty) {
                      final text = parts[0]['text'] as String;
                      if (text.isNotEmpty) {
                        yield text;
                      }
                    }
                  }
                }
              } catch (e) {
                print('Error parsing JSON: $e');
                print('JSON string: $jsonStr');
                continue;
              }
            }
          }
        } catch (e) {
          print('Error processing chunk: $e');
          print('Chunk: $chunk');
          continue;
        }
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('生成超时，请重试');
      }
      print('Gemini API error: $e');
      rethrow;
    }
  }

  Stream<String> _streamGeminiFlash({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getModelConfig(AIModel.geminiFlash);
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 Gemini API Key');
    }

    try {
      final uri = Uri.parse('${config.apiUrl}/models/gemini-1.5-flash:streamGenerateContent');
      final request = http.Request('POST', uri);
      
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-goog-api-key': config.apiKey,
      });

      request.body = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$systemPrompt\n\n$userPrompt'}
            ]
          }
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens,
          'topP': 0.8,
          'topK': 40,
        },
      });

      final response = await _client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('API 请求超时，请重试');
        },
      );
      
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('生成失败：$body');
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        try {
          if (chunk.trim().isEmpty) continue;

          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              if (jsonStr == '[DONE]') continue;

              try {
                final json = jsonDecode(jsonStr);
                if (json['candidates'] != null && json['candidates'].isNotEmpty) {
                  final content = json['candidates'][0]['content'];
                  if (content != null && content['parts'] != null) {
                    final parts = content['parts'] as List;
                    if (parts.isNotEmpty) {
                      final text = parts[0]['text'] as String;
                      if (text.isNotEmpty) {
                        yield text;
                      }
                    }
                  }
                }
              } catch (e) {
                print('Error parsing JSON: $e');
                print('JSON string: $jsonStr');
                continue;
              }
            }
          }
        } catch (e) {
          print('Error processing chunk: $e');
          print('Chunk: $chunk');
          continue;
        }
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('生成超时，请重试');
      }
      print('Gemini API error: $e');
      rethrow;
    }
  }

  Stream<String> _streamQwen({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getModelConfig(AIModel.qwen);
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置通义千问 API Key');
    }

    try {
      final response = await _postWithRetry(
        uri: Uri.parse('${config.apiUrl}/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': 'qwen-turbo-2024-11-01',
          'messages': [
            {
              'role': 'system',
              'content': '''作为一个专业的小说创作助手,请遵循以下要求:
1. 保持语言的多样性,避免重复使用相同的句式和词语
2. 每个段落使用不同的表达方式,增加文本的可读性
3. 合理使用修辞手法,让描写更加生动形象
4. 注意情节发展的连贯性,避免重复的剧情
5. 人物对话要有个性化的语言特点
6. 场景描写要细致入微,避免千篇一律
7. 情感表达要丰富多彩,不要局限于简单的词语
8. 故事节奏要富有变化,避免平铺直叙
请基于以上要求,创作出精彩的内容。''',
            },
            {
              'role': 'user',
              'content': userPrompt,
            },
          ],
          'temperature': 0.9,
          'max_tokens': maxTokens,
          'top_p': 0.95,
          'frequency_penalty': 0.5,
          'presence_penalty': 0.5,
          'stream': true,
        }),
      );

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          if (data == '[DONE]') continue;
          
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (e) {
            print('Error parsing chunk: $chunk');
            print('Error: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('Qwen API error: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }

  Future<String> generateText(String prompt) async {
    try {
      String response = '';
      await for (final chunk in generateTextStream(
        model: _apiConfig.selectedModel.value,
        systemPrompt: '''作为一个专业的小说创作助手，请遵循以下创作原则：

1. 故事逻辑：
   - 确保因果关系清晰合理，事件发展有其必然性
   - 人物行为要符合其性格特征和处境
   - 情节转折要有铺垫，避免突兀
   - 矛盾冲突的解决要符合逻辑
   - 故事背景要前后一致，细节要互相呼应

2. 叙事结构：
   - 采用灵活多变的叙事手法，避免单一直线式发展
   - 合理安排伏笔和悬念，让故事更有层次感
   - 注意时间线的合理性，避免前后矛盾
   - 场景转换要流畅自然，不生硬突兀
   - 故事节奏要有张弛，紧凑处突出戏剧性

3. 人物塑造：
   - 赋予角色丰富的心理活动和独特性格
   - 人物成长要符合其经历和环境
   - 人物关系要复杂立体，互动要自然
   - 对话要体现人物性格和身份特点
   - 避免脸谱化和类型化的人物描写

4. 环境描写：
   - 场景描写要与情节和人物情感相呼应
   - 细节要生动传神，突出关键特征
   - 环境氛围要配合故事发展
   - 感官描写要丰富多样
   - 避免无关的环境描写，保持紧凑

5. 语言表达：
   - 用词准确生动，避免重复和陈词滥调
   - 句式灵活多样，富有韵律感
   - 善用修辞手法，但不过分堆砌
   - 对话要自然流畅，符合说话人特点
   - 描写要细腻传神，避免空洞

请基于以上要求，创作出逻辑严密、情节生动、人物丰满的精彩内容。''',
        userPrompt: prompt,
      )) {
        response += chunk;
      }
      return response;
    } catch (e) {
      return '生成失败: $e';
    }
  }
} 