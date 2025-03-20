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
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 200; // 最小内容长度限制
    
    // 获取知识库控制器
    final knowledgeBaseController = Get.find<KnowledgeBaseController>();
    
    // 如果启用了知识库，使用知识库内容丰富提示词
    String basePrompt = prompt;
    if (knowledgeBaseController.useKnowledgeBase.value && knowledgeBaseController.selectedDocIds.isNotEmpty) {
      basePrompt = knowledgeBaseController.buildPromptWithKnowledge(prompt);
    }
    
    String enhancedPrompt = basePrompt;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        await for (final chunk in generateTextStream(
          systemPrompt: "你是一个专业的小说创作助手，请根据用户的要求提供高质量的内容。",
          userPrompt: enhancedPrompt,
          temperature: 0.7,
          maxTokens: 4000,
        )) {
          buffer.write(chunk);
        }
        
        final content = buffer.toString();
        
        // 检查内容长度是否符合要求
        if (content.length >= minLength) {
          completer.complete(content);
          break;
        } else {
          print('生成内容过短 (${content.length} < $minLength)，尝试重新生成 (尝试 $attempts/$maxRetries)');
          
          // 如果是最后一次尝试，返回已有内容而不是失败
          if (attempts >= maxRetries) {
            completer.complete(content);
            break;
          }
          
          // 增强提示词
          enhancedPrompt = '''$basePrompt
请提供更加详细和丰富的内容。上次生成的内容过短，需要更多的细节描述、情节发展、人物对话或场景描绘。请至少生成500字的内容。''';
          
          // 短暂延迟，避免API限速
          await Future.delayed(Duration(milliseconds: 500));
        }
      } catch (e) {
        print('生成内容错误: $e，尝试重新生成 (尝试 $attempts/$maxRetries)');
        
        if (attempts >= maxRetries) {
          completer.completeError('生成内容失败: $e');
          break;
        }
        
        // 短暂延迟，避免API限速
        await Future.delayed(Duration(seconds: 1));
      }
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
    List<Map<String, String>>? messages,
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
          // 构建Google API的消息格式
          List<Map<String, dynamic>> contents = [];
          
          if (messages != null && messages.isNotEmpty) {
            // 如果提供了历史消息，使用这些消息
            contents = messages.map((msg) => {
              'role': msg['role'],
              'parts': [{'text': msg['content']}]
            }).toList();
          } else {
            // 否则使用单一用户消息
            contents.add({
              'role': 'user',
              'parts': [{'text': '$systemPrompt\n\n$userPrompt'}]
            });
          }
          
          body = {
            'contents': contents,
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
          // 构建OpenAI格式的消息
          List<Map<String, String>> apiMessages = [];
          
          // 始终添加系统消息
          apiMessages.add({
            'role': 'system',
            'content': systemPrompt,
          });
          
          if (messages != null && messages.isNotEmpty) {
            // 添加历史消息
            apiMessages.addAll(messages);
          } else if (userPrompt.isNotEmpty) {
            // 如果没有历史消息但有用户消息，添加用户消息
            apiMessages.add({
              'role': 'user',
              'content': userPrompt,
            });
          }
          
          body = {
            'messages': apiMessages,
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
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 500; // 章节最小长度限制，章节内容应该更长
    
    // 获取知识库控制器
    final knowledgeBaseController = Get.find<KnowledgeBaseController>();
    
    // 如果启用了知识库，使用知识库内容丰富提示词
    String basePrompt = prompt;
    if (knowledgeBaseController.useKnowledgeBase.value && knowledgeBaseController.selectedDocIds.isNotEmpty) {
      basePrompt = knowledgeBaseController.buildPromptWithKnowledge(prompt);
    }
    
    String enhancedPrompt = basePrompt;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        await for (final chunk in generateChapterTextStream(
          systemPrompt: "你是一个专业的小说章节创作助手，请根据用户的需求提供高质量、有代入感的章节内容。内容要有丰富的情节、生动的描写和自然的对话。",
          userPrompt: enhancedPrompt,
          temperature: 0.75,
          maxTokens: 4000,
        )) {
          buffer.write(chunk);
        }
        
        final content = buffer.toString();
        
        // 检查内容长度是否符合要求
        if (content.length >= minLength) {
          completer.complete(content);
          break;
        } else {
          print('章节内容过短 (${content.length} < $minLength)，尝试重新生成 (尝试 $attempts/$maxRetries)');
          
          // 如果是最后一次尝试，返回已有内容而不是失败
          if (attempts >= maxRetries) {
            completer.complete(content);
            break;
          }
          
          // 增强提示词
          enhancedPrompt = '''$basePrompt
请提供更详细的章节内容，包含更多细节描写、人物对话和情节发展。上次生成的内容过于简短，需要扩展。请至少生成800字以上的完整章节。''';
          
          // 短暂延迟，避免API限速
          await Future.delayed(Duration(milliseconds: 500));
        }
      } catch (e) {
        print('生成章节内容错误: $e，尝试重新生成 (尝试 $attempts/$maxRetries)');
        
        if (attempts >= maxRetries) {
          completer.completeError('生成章节内容失败: $e');
          break;
        }
        
        // 短暂延迟，避免API限速
        await Future.delayed(Duration(seconds: 1));
      }
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

  Future<String> generateOutline(String prompt) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 150; // 大纲最小长度限制
    String enhancedPrompt = prompt;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        await for (final chunk in generateTextStream(
          systemPrompt: "你是一个专业的小说大纲创作助手，请根据用户的需求提供完整的情节大纲。大纲要包含清晰的起承转合，角色线索和主要冲突。确保每个章节之间情节连贯，角色发展合理。请为每章节设计与整体情节结构相符的内容，避免逻辑断层和人物行动不一致。",
          userPrompt: enhancedPrompt,
          temperature: 0.7,
          maxTokens: 2000,
        )) {
          buffer.write(chunk);
        }
        
        String content = buffer.toString();
        
        if (content.length < minLength) {
          if (attempts < maxRetries) {
            enhancedPrompt = "$prompt\n\n你的上一次回答太简短了，请提供更详细的大纲内容，至少需要包含主要情节线和次要情节线，以及每个重要章节的具体内容描述。确保情节线连贯，角色发展一致。至少需要${minLength * 2}个字符。";
            continue;
          }
        }
        
        completer.complete(content);
        break;
      } catch (e) {
        print('生成大纲失败，尝试次数：$attempts，错误：$e');
        if (attempts >= maxRetries) {
          completer.completeError('生成大纲失败：$e');
          break;
        }
        
        await Future.delayed(Duration(seconds: 1));
      }
    }
    
    return completer.future;
  }

  // 使用大纲模型生成更智能、更连贯的大纲
  Future<String> generateSmartOutline({
    required String prompt,
    required String? previousContent,
    double? temperature,
    int? maxTokens,
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 200; // 大纲最小长度限制
    
    // 构建考虑连贯性的提示词
    String enhancedPrompt = prompt;
    if (previousContent != null && previousContent.isNotEmpty) {
      enhancedPrompt = '''
这是已经生成的大纲内容：
$previousContent

请基于以上大纲内容继续生成，确保情节连贯，人物发展合理：
$prompt

要求：
1. 严格遵循之前生成内容中的设定、人物特征和关系
2. 确保情节发展合理，与前文相衔接
3. 避免出现前后矛盾或逻辑断层
4. 人物行为和对话要符合其性格特点和动机
''';
    }
    
    final outlineModel = _apiConfig.getOutlineModel();
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        await for (final chunk in generateTextStream(
          systemPrompt: '''你是一个专业的小说大纲创作助手，负责创作高质量、情节连贯的小说大纲。
你的任务是生成符合用户要求的大纲内容，同时确保：
1. 大纲逻辑连贯，情节发展自然
2. 人物性格一致，行为合理
3. 设定没有冲突
4. 每个章节都有明确的剧情推进
5. 主要情节线清晰可见，副线索合理穿插

在生成内容时，请仔细分析用户提供的要求和任何前序大纲内容，确保新生成的内容与之前的内容保持高度连贯性。''',
          userPrompt: enhancedPrompt,
          temperature: temperature ?? outlineModel.temperature,
          topP: outlineModel.topP,
          maxTokens: maxTokens ?? outlineModel.maxTokens,
          repetitionPenalty: outlineModel.repetitionPenalty,
          specificModelConfig: outlineModel,
        )) {
          buffer.write(chunk);
        }
        
        String content = buffer.toString();
        
        // 检查内容长度
        if (content.length < minLength) {
          if (attempts < maxRetries) {
            enhancedPrompt = '''
$enhancedPrompt

你的上一次回答太简短了，请提供更详细的大纲内容。要包含：
- 更详细的情节描述
- 更丰富的人物互动
- 更清晰的冲突和转折
- 至少生成${minLength * 2}个字符
''';
            
            await Future.delayed(Duration(milliseconds: 500));
            continue;
          }
        }
        
        completer.complete(content);
        break;
      } catch (e) {
        print('生成智能大纲失败，尝试次数：$attempts，错误：$e');
        if (attempts >= maxRetries) {
          completer.completeError('生成智能大纲失败：$e');
          break;
        }
        
        await Future.delayed(Duration(seconds: 1));
      }
    }
    
    return completer.future;
  }

  // 非流式生成文本内容的方法
  Future<String> generateText({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    double topP = 1.0,
    int? maxTokens,
    double repetitionPenalty = 1.3,
    List<Map<String, String>>? messages,
  }) async {
    // 构建一个StringBuffer来收集流式结果
    final buffer = StringBuffer();
    try {
      // 使用流式API，但合并结果
      await for (final chunk in generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        repetitionPenalty: repetitionPenalty,
        messages: messages,
      )) {
        buffer.write(chunk);
      }
      return buffer.toString();
    } catch (e) {
      print('生成文本失败: $e');
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