import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum AIModel {
  deepseek,
  qwen,
  geminiPro,
  geminiFlash,
}

class AIService extends GetxService {
  final ApiConfigController _apiConfig;
  final _client = http.Client();
  final _timeout = const Duration(seconds: 30);
  final _maxRetries = 10;  // 最大重试次数
  final _retryInterval = const Duration(seconds: 1);  // 重试间隔
  final bool _isWeb = kIsWeb;  // 添加 Web 平台判断

  AIService(this._apiConfig);

  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 8000,  // 增加默认token限制
    double temperature = 0.8,
  }) async* {
    int attempts = 0;
    DateTime startTime = DateTime.now();
    
    print('开始生成文本流');
    print('运行环境: ${_isWeb ? 'Web' : 'Native'}');
    
    while (attempts < _maxRetries) {
      attempts++;
      print('尝试第 $attempts/$_maxRetries 次请求');
      
      try {
        final currentModel = _apiConfig.getCurrentModel();
        print('当前模型: ${currentModel.model}');
        print('API格式: ${currentModel.apiFormat}');
        
        switch (currentModel.apiFormat) {
          case 'OpenAI API兼容':
            yield '正在连接 AI 服务...\n';
            print('使用 OpenAI 兼容API');
            if (_isWeb) {
              print('使用Web专用流处理');
              yield* _streamOpenAIAPIWeb(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                maxTokens: maxTokens,
                temperature: temperature,
              );
            } else {
              print('使用原生流处理');
              yield* _streamOpenAIAPI(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                maxTokens: maxTokens,
                temperature: temperature,
              );
            }
            print('请求成功！');
            print('耗时：${DateTime.now().difference(startTime).inSeconds}秒');
            return;
          case 'Google API':
            yield '正在连接 Google AI 服务...\n';
            print('使用 Google API');
            if (_isWeb) {
              print('使用Web专用流处理');
              yield* _streamGoogleAPIWeb(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                maxTokens: maxTokens,
                temperature: temperature,
              );
            } else {
              print('使用原生流处理');
              yield* _streamGoogleAPI(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                maxTokens: maxTokens,
                temperature: temperature,
              );
            }
            print('请求成功！');
            print('耗时：${DateTime.now().difference(startTime).inSeconds}秒');
            return;
          default:
            throw Exception('不支持的API格式：${currentModel.apiFormat}');
        }
      } catch (e) {
        print('发生错误：$e');
        print('错误堆栈：${StackTrace.current}');
        
        if (e is TimeoutException) {
          yield '请求超时，正在重试...\n';
        } else {
          yield '发生错误，正在重试：${e.toString()}\n';
        }
        
        if (attempts >= _maxRetries) {
          yield '达到最大重试次数，请求失败。\n具体错误：${e.toString()}\n请检查：\n1. 网络连接是否正常\n2. API 配置是否正确\n3. API 余额是否充足';
          rethrow;
        }
        await Future.delayed(_retryInterval);
        continue;
      }
    }
  }

  Future<http.StreamedResponse> _postWithRetry({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    int retryCount = 0,
  }) async {
    DateTime startTime = DateTime.now();
    int attempts = 0;

    while (attempts < _maxRetries) {
      attempts++;
      try {
        final request = http.Request('POST', uri)
          ..headers.addAll(headers)
          ..body = body;

        final response = await _client.send(request).timeout(
          _timeout,
          onTimeout: () {
            throw TimeoutException('API 请求超时，请检查网络连接');
          },
        );
        
        if (response.statusCode == 200) {
          print('API请求成功！');
          print('耗时：${DateTime.now().difference(startTime).inSeconds}秒');
          return response;
        } else if (response.statusCode >= 500 && attempts < _maxRetries) {
          print('服务器错误，状态码：${response.statusCode}');
          await Future.delayed(_retryInterval * attempts);
          continue;
        } else {
          final responseBody = await response.stream.bytesToString();
          throw Exception('API 请求失败：状态码 ${response.statusCode}\n响应：$responseBody');
        }
      } catch (e) {
        print('第$attempts次请求失败：$e');
        if (attempts >= _maxRetries) {
          print('达到最大重试次数，请求失败。');
          rethrow;
        }
        await Future.delayed(_retryInterval * attempts);
        continue;
      }
    }
    throw Exception('超过最大重试次数');
  }

  Stream<String> _streamOpenAIAPI({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getCurrentModel();
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }

    try {
      final response = await _postWithRetry(
        uri: Uri.parse('${config.apiUrl}${config.apiPath}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': config.apiKey.startsWith('Bearer ') ? config.apiKey : 'Bearer ${config.apiKey}',
        },
        body: jsonEncode({
          'model': config.model,
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
          'parameters': {
            'temperature': temperature,
            'max_tokens': maxTokens,
            'top_p': config.topP,
          },
          'stream': true,
          'user_id': config.appId,
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
      print('API error: $e');
      rethrow;
    }
  }

  Stream<String> _streamGoogleAPI({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getCurrentModel();
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }

    try {
      final uri = Uri.parse('${config.apiUrl}${config.apiPath}');
      final request = http.Request('POST', uri);
      
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-goog-api-key': config.apiKey.startsWith('Bearer ') ? config.apiKey.substring(7) : config.apiKey,
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
          'topP': config.topP,
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
      print('API error: $e');
      rethrow;
    }
  }

  // 为 Web 平台添加特殊的 OpenAI API 流处理
  Stream<String> _streamOpenAIAPIWeb({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getCurrentModel();
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }

    try {
      print('准备发送请求到: ${config.apiUrl}${config.apiPath}');
      
      final response = await http.post(
        Uri.parse('${config.apiUrl}${config.apiPath}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': config.apiKey.startsWith('Bearer ') ? config.apiKey : 'Bearer ${config.apiKey}',
          'Accept': 'text/event-stream',
        },
        body: jsonEncode({
          'model': config.model,
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
          'stream': true,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'top_p': config.topP,
        }),
      );

      print('收到响应，状态码: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        throw Exception('API请求失败: ${response.body}');
      }

      final lines = response.body.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          
          try {
            final json = jsonDecode(data);
            if (json['choices'] != null && 
                json['choices'].isNotEmpty && 
                json['choices'][0]['delta'] != null &&
                json['choices'][0]['delta']['content'] != null) {
              final content = json['choices'][0]['delta']['content'] as String;
              if (content.isNotEmpty) {
                print('生成内容: $content');
                yield content;
              }
            }
          } catch (e) {
            print('解析数据失败: $e');
            print('原始数据: $data');
            continue;
          }
        }
      }
    } catch (e) {
      print('API调用失败: $e');
      rethrow;
    }
  }

  // 为 Web 平台添加特殊的 Google API 流处理
  Stream<String> _streamGoogleAPIWeb({
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) async* {
    final config = _apiConfig.getCurrentModel();
    if (config.apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }

    try {
      print('准备发送请求到: ${config.apiUrl}${config.apiPath}');
      
      final response = await http.post(
        Uri.parse('${config.apiUrl}${config.apiPath}'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey.startsWith('Bearer ') ? config.apiKey.substring(7) : config.apiKey,
          'Accept': 'text/event-stream',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': '$systemPrompt\n\n$userPrompt'}]
            }
          ],
          'generationConfig': {
            'temperature': temperature,
            'maxOutputTokens': maxTokens,
            'topP': config.topP,
            'topK': 40,
          },
        }),
      );

      print('收到响应，状态码: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        throw Exception('API请求失败: ${response.body}');
      }

      final lines = response.body.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          
          try {
            final json = jsonDecode(data);
            if (json['candidates'] != null && 
                json['candidates'].isNotEmpty && 
                json['candidates'][0]['content'] != null &&
                json['candidates'][0]['content']['parts'] != null) {
              final parts = json['candidates'][0]['content']['parts'] as List;
              if (parts.isNotEmpty) {
                final text = parts[0]['text'] as String;
                if (text.isNotEmpty) {
                  print('生成内容: $text');
                  yield text;
                }
              }
            }
          } catch (e) {
            print('解析数据失败: $e');
            print('原始数据: $data');
            continue;
          }
        }
      }
    } catch (e) {
      print('API调用失败: $e');
      rethrow;
    }
  }

  // 添加一个新的方法来检查 API 连接
  Future<bool> checkApiConnection() async {
    try {
      final config = _apiConfig.getCurrentModel();
      final response = await http.get(Uri.parse(config.apiUrl));
      return response.statusCode == 200;
    } catch (e) {
      print('API连接检查失败: $e');
      return false;
    }
  }

  Future<String> generateChapterContent(String prompt) async {
    try {
      String response = '';
      await for (final chunk in generateTextStream(
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
        maxTokens: 8000,
        temperature: 0.8,
      )) {
        response += chunk;
      }
      return response;
    } catch (e) {
      print('生成章节内容失败: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}

// 添加一个 StreamReader 类来帮助处理 Web 平台的流
class StreamReader {
  final Stream<List<int>> stream;
  List<int> _buffer = [];
  final _utf8Decoder = utf8.decoder;

  StreamReader(this.stream);

  Future<String?> readLine() async {
    final completer = Completer<String?>();
    
    await for (final chunk in stream) {
      _buffer.addAll(chunk);
      
      final lineEnd = _buffer.indexOf('\n'.codeUnitAt(0));
      if (lineEnd >= 0) {
        final line = _utf8Decoder.convert(_buffer.sublist(0, lineEnd));
        _buffer = _buffer.sublist(lineEnd + 1);
        completer.complete(line);
        return completer.future;
      }
    }
    
    if (_buffer.isNotEmpty) {
      final line = _utf8Decoder.convert(_buffer);
      _buffer = [];
      return line;
    }
    
    return null;
  }
} 