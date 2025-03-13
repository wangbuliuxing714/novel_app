import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:novel_app/controllers/knowledge_base_controller.dart';

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

  Future<String> generateContent(String prompt) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    try {
      await for (final chunk in generateTextStream(
        systemPrompt: "你是一个专业的小说创作助手，请根据用户的要求提供高质量的内容。",
        userPrompt: prompt,
        temperature: 0.7,
        maxTokens: 4000,
      )) {
        buffer.write(chunk);
      }
      
      completer.complete(buffer.toString());
    } catch (e) {
      completer.completeError('生成内容失败: $e');
    }
    
    return completer.future;
  }

  Stream<String> generateTextStream({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    double topP = 1.0,
    int? maxTokens,
    double repetitionPenalty = 1.3,
    ModelConfig? specificModelConfig,
  }) async* {
    final modelConfig = specificModelConfig ?? _apiConfig.getCurrentModel();
    final apiKey = modelConfig.apiKey;
    final apiUrl = modelConfig.apiUrl;
    final apiPath = modelConfig.apiPath;
    final model = modelConfig.model;
    final apiFormat = modelConfig.apiFormat;
    final appId = modelConfig.appId;

    if (apiKey.isEmpty) {
      throw Exception('API密钥未设置');
    }

    final client = http.Client();
    final uri = Uri.parse('$apiUrl$apiPath');
    int retryCount = 0;
    const maxRetries = 3; // 最大重试次数
    
    while (true) {
      try {
        // 添加调试日志
        print('===== API调用信息 =====');
        print('API格式: $apiFormat');
        print('API URL: $apiUrl$apiPath');
        print('模型: $model');
        print('重试次数: $retryCount');
        
        final Map<String, dynamic> body;
        
        // 根据不同API格式构建请求体
        if (apiFormat == 'Google API') {
          body = {
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
              'topP': topP,
              'maxOutputTokens': maxTokens ?? 4000,
              'repetitionPenalty': repetitionPenalty,
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_NONE'
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_NONE'
              },
              {
                'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                'threshold': 'BLOCK_NONE'
              },
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_NONE'
              }
            ]
          };
          
          // 判断是否使用流式处理，如果API路径中包含stream则添加
          if (!apiPath.contains('stream')) {
            body['stream'] = true;
          }
        } else {
          body = {
            'messages': [
              {
                'role': 'system',
                'content': systemPrompt,
              },
              {
                'role': 'user',
                'content': userPrompt,
              }
            ],
            'model': model,
            'temperature': temperature,
            'top_p': topP,
            'max_tokens': maxTokens,
            'presence_penalty': 0,
            'frequency_penalty': repetitionPenalty,
            'stream': true,
          };
        }

        Map<String, String> headers = {
          'Content-Type': 'application/json',
        };

        // 设置不同API的认证头
        if (apiFormat == 'Google API') {
          // Google API使用API密钥而不是Bearer令牌
          headers['x-goog-api-key'] = apiKey;
        } else if (appId.isNotEmpty) {
          // 百度千帆API需要额外的appId
          headers['X-Bce-Authorization'] = apiKey;
          headers['X-Appid'] = appId;
        } else {
          // 默认使用Bearer认证（OpenAI兼容API）
          headers['Authorization'] = 'Bearer $apiKey';
        }

        final request = http.Request('POST', uri)
          ..headers.addAll(headers)
          ..body = jsonEncode(body);

        // 设置更长的超时时间
        final streamedResponse = await client.send(request).timeout(
          Duration(seconds: 30 + (retryCount * 5)), // 随着重试次数增加超时时间
          onTimeout: () {
            throw TimeoutException('API请求超时，请检查网络连接');
          },
        );

        // 记录响应状态
        print('===== API响应状态 =====');
        print('状态码: ${streamedResponse.statusCode}');
        print('响应头: ${streamedResponse.headers}');

        if (streamedResponse.statusCode != 200) {
          final errorBody = await streamedResponse.stream.bytesToString();
          print('错误响应内容: $errorBody');
          
          // 如果是服务器错误且未超过最大重试次数，则重试
          if (streamedResponse.statusCode >= 500 && retryCount < maxRetries) {
            retryCount++;
            await Future.delayed(Duration(seconds: 2 * retryCount)); // 指数退避
            continue; // 重试
          }
          
          throw Exception('API请求失败，状态码: ${streamedResponse.statusCode}，错误: $errorBody');
        }

        // 处理流式响应
        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          if (chunk.trim().isEmpty) continue;

          // 记录接收到的数据块（仅供调试）
          if (apiFormat == 'Google API') {
            print('===== Gemini 响应数据块 =====');
            print(chunk.substring(0, chunk.length > 100 ? 100 : chunk.length) + '...');
          }

          try {
            if (apiFormat == 'Google API') {
              // 处理Gemini响应
              try {
                final data = jsonDecode(chunk);
                
                // 检查是否有错误
                if (data['error'] != null) {
                  print('Gemini API错误: ${data['error']}');
                  continue;
                }
                
                // 获取内容
                if (data['candidates'] != null && data['candidates'].isNotEmpty) {
                  var candidate = data['candidates'][0];
                  
                  // 检查是否有内容更新
                  if (candidate['content'] != null && 
                      candidate['content']['parts'] != null && 
                      candidate['content']['parts'].isNotEmpty) {
                    
                    var text = candidate['content']['parts'][0]['text'];
                    if (text != null && text.toString().isNotEmpty) {
                      yield text.toString();
                    }
                  }
                }
              } catch (e) {
                print('解析Gemini响应失败: $e');
                print('原始数据: ${chunk.length > 500 ? chunk.substring(0, 500) + "..." : chunk}');
                continue;
              }
            } else {
              // 处理OpenAI兼容API响应
              final lines = chunk.split('\n');
              for (final line in lines) {
                if (line.startsWith('data: ')) {
                  final data = line.substring(6);
                  if (data == '[DONE]') continue;
                  
                  try {
                    final json = jsonDecode(data);
                    if (json['choices'] != null &&
                        json['choices'][0]['delta'] != null &&
                        json['choices'][0]['delta']['content'] != null) {
                      yield json['choices'][0]['delta']['content'];
                    }
                  } catch (e) {
                    print('解析JSON失败: $e');
                    print('原始数据: $data');
                    continue;
                  }
                }
              }
            }
          } catch (e) {
            print('处理响应数据块出错: $e');
            // 继续处理下一个数据块
          }
        }
        
        // 如果成功处理了所有响应，退出循环
        break;
        
      } catch (e) {
        print('API调用出错: $e');
        
        // 连接错误时进行重试
        if ((e is SocketException || e is TimeoutException) && retryCount < maxRetries) {
          retryCount++;
          print('第 $retryCount 次重试...');
          await Future.delayed(Duration(seconds: 2 * retryCount)); // 指数退避
          continue;
        }
        
        // 转换Gemini特定错误为更友好的消息
        if (e.toString().contains('generativelanguage.googleapis.com')) {
          throw Exception('无法连接到Google Gemini API，这可能是由于网络问题导致的。请尝试使用"Gemini代理版"模型，或使用其他模型。');
        }
        
        // 重新抛出其他错误
        rethrow;
      } finally {
        if (retryCount >= maxRetries) {
          client.close();
        }
      }
    }
    
    client.close();
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
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    try {
      // 获取知识库控制器
      final knowledgeBaseController = Get.find<KnowledgeBaseController>();
      
      // 如果启用了知识库，使用知识库内容丰富提示词
      String finalPrompt = prompt;
      if (knowledgeBaseController.useKnowledgeBase.value && knowledgeBaseController.selectedDocIds.isNotEmpty) {
        finalPrompt = knowledgeBaseController.buildPromptWithKnowledge(prompt);
      }
      
      await for (final chunk in generateChapterTextStream(
        systemPrompt: finalPrompt,
        userPrompt: "请根据以上要求生成章节内容",
        temperature: 0.7,
        maxTokens: 4000,
      )) {
        buffer.write(chunk);
      }
      
      completer.complete(buffer.toString());
    } catch (e) {
      completer.completeError('生成章节内容失败: $e');
    }
    
    return completer.future;
  }

  // 添加生成短篇小说大纲的方法
  Future<String> generateShortNovelOutline(String prompt) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    try {
      // 获取知识库控制器
      final knowledgeBaseController = Get.find<KnowledgeBaseController>();
      
      // 如果启用了知识库，使用知识库内容丰富提示词
      String finalPrompt = prompt;
      if (knowledgeBaseController.useKnowledgeBase.value && knowledgeBaseController.selectedDocIds.isNotEmpty) {
        finalPrompt = knowledgeBaseController.buildPromptWithKnowledge(prompt);
      }
      
      await for (final chunk in generateOutlineTextStream(
        systemPrompt: finalPrompt,
        userPrompt: "请为我创建一个详细的短篇小说大纲，确保结构完整合理",
        temperature: 0.7,
        maxTokens: 3000, // 增加token上限以确保完整的五段式大纲
        repetitionPenalty: 1.05, // 降低重复惩罚
      )) {
        buffer.write(chunk);
      }
      
      completer.complete(buffer.toString());
    } catch (e) {
      completer.completeError('生成短篇小说大纲失败: $e');
    }
    
    return completer.future;
  }
  
  // 添加生成短篇小说内容的方法
  Future<String> generateShortNovelContent(String prompt) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    try {
      // 获取知识库控制器
      final knowledgeBaseController = Get.find<KnowledgeBaseController>();
      
      // 如果启用了知识库，使用知识库内容丰富提示词
      String finalPrompt = prompt;
      if (knowledgeBaseController.useKnowledgeBase.value && knowledgeBaseController.selectedDocIds.isNotEmpty) {
        finalPrompt = knowledgeBaseController.buildPromptWithKnowledge(prompt);
      }
      
      await for (final chunk in generateChapterTextStream(
        systemPrompt: finalPrompt,
        userPrompt: "请根据以上要求创作一篇高质量的短篇小说内容",
        temperature: 0.78, // 提高创造性
        maxTokens: 8000, // 最大token上限
        repetitionPenalty: 1.0, // 不进行重复惩罚，允许更自然的文学表达
        topP: 0.95, // 提高多样性
      )) {
        buffer.write(chunk);
      }
      
      completer.complete(buffer.toString());
    } catch (e) {
      completer.completeError('生成短篇小说内容失败: $e');
    }
    
    return completer.future;
  }

  // 使用大纲模型生成内容
  Stream<String> generateOutlineTextStream({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
  }) async* {
    final outlineModel = _apiConfig.getOutlineModel();
    yield* generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? outlineModel.temperature,
      topP: topP ?? outlineModel.topP,
      maxTokens: maxTokens ?? outlineModel.maxTokens,
      repetitionPenalty: repetitionPenalty ?? outlineModel.repetitionPenalty,
      specificModelConfig: outlineModel,
    );
  }

  // 使用章节模型生成内容
  Stream<String> generateChapterTextStream({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
  }) async* {
    final chapterModel = _apiConfig.getChapterModel();
    yield* generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? chapterModel.temperature,
      topP: topP ?? chapterModel.topP,
      maxTokens: maxTokens ?? chapterModel.maxTokens,
      repetitionPenalty: repetitionPenalty ?? chapterModel.repetitionPenalty,
      specificModelConfig: chapterModel,
    );
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