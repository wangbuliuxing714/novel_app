import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:novel_app/controllers/knowledge_base_controller.dart';
import 'package:novel_app/services/conversation_manager.dart';

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

  // 恢复为简单的小说标题到对话ID的映射
  final Map<String, String> _novelConversationIds = {};
  
  AIService(this._apiConfig);

  // 获取或创建小说的对话ID - 简化回最初版本
  String _getNovelConversationId(String novelTitle) {
    if (!_novelConversationIds.containsKey(novelTitle)) {
      _novelConversationIds[novelTitle] = ConversationManager.createConversation();
      print('为小说"$novelTitle"创建对话ID: ${_novelConversationIds[novelTitle]}');
    }
    return _novelConversationIds[novelTitle]!;
  }

  // 简化清除方法
  void clearNovelConversation(String novelTitle) {
    final conversationId = _novelConversationIds[novelTitle];
    if (conversationId != null) {
      ConversationManager.clearConversation(conversationId);
      _novelConversationIds.remove(novelTitle);
      print('已清除小说"$novelTitle"的对话历史');
    }
  }

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
    String? conversationId,
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
    
    // 如果提供了conversationId，则使用对话历史，否则直接使用系统提示词和用户提示词
    List<Map<String, dynamic>> messages = [];
    if (conversationId != null) {
      // 使用已有的对话历史
      messages = ConversationManager.getMessages(conversationId);
      
      // 打印对话历史，帮助调试
      print('===== 对话历史 (ID: $conversationId) =====');
      print('对话历史条数: ${messages.length}');
      for (var i = 0; i < messages.length; i++) {
        var msg = messages[i];
        print('消息[$i] - ${msg['role']}: ${(msg['content'] as String).length > 50 ? (msg['content'] as String).substring(0, 50) + "..." : msg['content']}');
      }
      
      // 检查对话历史中是否有大纲内容
      bool hasOutline = false;
      for (final msg in messages) {
        if (msg['role'] == 'assistant' && 
            (msg['content'] as String).contains('大纲') && 
            (msg['content'] as String).length > 100) {
          hasOutline = true;
          print('对话历史中包含大纲内容');
          break;
        }
      }
      
      if (!hasOutline) {
        print('警告: 对话历史中不包含大纲内容');
      }
      
      // 如果对话历史为空，添加系统提示词
      if (messages.isEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt
        });
      }
      
      // 添加用户提示词
      messages.add({
        'role': 'user',
        'content': userPrompt
      });
      
      // 更新对话历史
      ConversationManager.addMessage(conversationId, 'user', userPrompt);
    } else {
      // 使用单次对话模式
      messages = [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {
          'role': 'user',
          'content': userPrompt,
        }
      ];
    }
    
    while (true) {
      try {
        // 添加调试日志
        print('===== API调用信息 =====');
        print('API格式: $apiFormat');
        print('API URL: $apiUrl$apiPath');
        print('模型: $model');
        print('重试次数: $retryCount');
        print('使用对话ID: ${conversationId ?? "无"}');
        
        final Map<String, dynamic> body;
        
        // 根据不同API格式构建请求体
        if (apiFormat == 'Google API') {
          // Google API 不支持对话历史格式，需要手动合并
          String combinedPrompt = systemPrompt;
          if (conversationId != null) {
            final historyMessages = ConversationManager.getMessages(conversationId);
            for (var i = 0; i < historyMessages.length - 1; i++) { // 不包括最后一条用户消息
              if (historyMessages[i]['role'] != 'system') {
                combinedPrompt += '\n\n${historyMessages[i]['role']}: ${historyMessages[i]['content']}';
              }
            }
            combinedPrompt += '\n\n最新问题：$userPrompt';
          }
          
          body = {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': combinedPrompt}
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
          // OpenAI格式API
          // 确保messages数组符合OpenAI格式
          List<Map<String, dynamic>> formattedMessages = [];
          
          // 首先添加系统消息（如果存在）
          bool hasSystemMessage = false;
          for (var msg in messages) {
            if (msg['role'] == 'system') {
              formattedMessages.add(msg);
              hasSystemMessage = true;
              break;
            }
          }
          
          // 如果没有系统消息，添加默认系统消息
          if (!hasSystemMessage) {
            formattedMessages.add({
              'role': 'system',
              'content': systemPrompt
            });
          }
          
          // 添加非系统消息
          for (var msg in messages) {
            if (msg['role'] != 'system') {
              // 确保消息角色符合OpenAI要求
              if (msg['role'] == 'assistant' || msg['role'] == 'user') {
                formattedMessages.add(msg);
              }
            }
          }
          
          // 检查最后一条消息是否是用户的
          if (formattedMessages.isNotEmpty && 
              formattedMessages.last['role'] != 'user') {
            // 确保最后一条是用户消息
            formattedMessages.add({
              'role': 'user',
              'content': userPrompt
            });
          }
          
          print('格式化后的消息数: ${formattedMessages.length}');
          for (var i = 0; i < formattedMessages.length; i++) {
            var msg = formattedMessages[i];
            print('格式化消息[$i] - ${msg['role']}: ${(msg['content'] as String).length > 30 ? (msg['content'] as String).substring(0, 30) + "..." : msg['content']}');
          }
          
          body = {
            'messages': formattedMessages,
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

        String responseContent = '';
        
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
                      responseContent += text.toString();
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
                      final content = json['choices'][0]['delta']['content'];
                      responseContent += content;
                      yield content;
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
        
        // 如果使用对话ID，将AI的回复添加到对话历史
        if (conversationId != null && responseContent.isNotEmpty) {
          ConversationManager.addMessage(conversationId, 'assistant', responseContent);
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

  Future<String> generateChapterContent(String prompt, {String? novelTitle, int? chapterNumber, String? outlineContent}) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 500; // 章节最小长度限制，章节内容应该更长
    
    // 获取知识库控制器
    final knowledgeBaseController = Get.find<KnowledgeBaseController>();
    
    // 获取或创建小说的对话ID
    String? conversationId;
    if (novelTitle != null) {
      conversationId = _getNovelConversationId(novelTitle);
      print('使用小说"$novelTitle"的对话ID: $conversationId');
      
      // 检查对话历史中是否有大纲信息
      if (conversationId != null) {
        final messages = ConversationManager.getMessages(conversationId);
        bool hasOutline = false;
        
        for (final message in messages) {
          if (message['role'] == 'assistant' && 
              message['content'].toString().contains('大纲') && 
              message['content'].toString().length > 200) {
            hasOutline = true;
            print('对话历史中已存在大纲信息');
            break;
          }
        }
        
        if (!hasOutline && outlineContent == null) {
          print('警告：对话历史中没有发现大纲信息，章节生成可能与大纲不匹配');
        }
      }
    }
    
    // 如果启用了知识库，使用知识库内容丰富提示词
    String basePrompt = prompt;
    if (knowledgeBaseController.useKnowledgeBase.value && knowledgeBaseController.selectedDocIds.isNotEmpty) {
      basePrompt = knowledgeBaseController.buildPromptWithKnowledge(prompt);
    }
    
    // 如果提供了大纲内容，将其添加到提示中
    if (outlineContent != null && outlineContent.isNotEmpty) {
      basePrompt = '''
【小说整体大纲】
$outlineContent

【本章节要求】
$basePrompt

【重要说明】
1. 你必须严格按照上述大纲内容生成本章节
2. 本章节内容必须与大纲保持一致，不得偏离大纲的主要情节
3. 确保人物、背景和世界观设定与大纲一致
''';

      // 如果对话历史中没有大纲信息，将大纲添加到对话历史中
      if (conversationId != null) {
        final messages = ConversationManager.getMessages(conversationId);
        bool hasOutline = false;
        
        for (final message in messages) {
          if (message['role'] == 'assistant' && 
              message['content'].toString().contains('大纲')) {
            hasOutline = true;
            break;
          }
        }
        
        if (!hasOutline) {
          print('将大纲添加到对话历史中');
          
          // 首先清除可能存在的旧消息
          ConversationManager.clearConversation(conversationId);
          
          // 添加系统指令，明确如何使用大纲
          ConversationManager.addMessage(conversationId, 'system', 
            "你是一个专业的小说章节创作助手。你必须严格按照小说大纲生成章节内容，确保情节连贯，人物和世界观设定一致。每个章节必须与大纲中描述的内容相符。");
          
          // 添加大纲作为助手消息
          ConversationManager.addMessage(conversationId, 'assistant', 
            "这部小说的大纲如下:\n\n```\n" + outlineContent + "\n```\n\n我会根据这个大纲来创作每个章节。");
          
          // 添加用户确认
          ConversationManager.addMessage(conversationId, 'user', 
            "非常好的大纲，请记住这个大纲并根据它创作具体章节。");
          
          // 添加助手确认
          ConversationManager.addMessage(conversationId, 'assistant', 
            "我已经理解并记住了这个大纲。创作章节时，我会严格遵循大纲中的情节发展，确保角色和世界观的一致性。");
        }
      }
    }
    
    // 增强提示词，强调内容的连贯性
    basePrompt = '''
$basePrompt

【连贯性要求】
你必须确保生成的内容与前文高度连贯，特别注意：
1. 人物形象、性格、能力和关系必须与前文一致
2. 情节发展必须基于前文已有的铺垫，不得随意创造新线索
3. 世界观设定（如魔法规则、科技水平、社会结构等）必须与前文保持一致
4. 提及的地点、物品、概念应该正确引用前文
5. 人物的语言风格和习惯必须保持一致

请仔细阅读【前序章节详细内容】，确保新生成的内容是前文的自然延续，而不是割裂的新故事。
''';
    
    String enhancedPrompt = basePrompt;
    String systemPrompt = "你是一个专业的小说章节创作助手，请根据用户的需求提供高质量、有代入感的章节内容。内容要有丰富的情节、生动的描写和自然的对话。你必须严格保持与前文的连贯性，记住并正确引用前文中的所有关键情节、人物特征和设定。你的任务是创作出一个既符合当前章节大纲要求、又与前文自然衔接的优质章节。";
    
    // 对于首次对话，设置系统提示词
    if (conversationId != null && ConversationManager.getMessages(conversationId).isEmpty) {
      ConversationManager.addMessage(conversationId, 'system', systemPrompt);
    }
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        await for (final chunk in generateChapterTextStream(
          systemPrompt: systemPrompt,
          userPrompt: enhancedPrompt,
          temperature: 0.75,
          maxTokens: 4000,
          conversationId: conversationId, // 使用对话ID
        )) {
          buffer.write(chunk);
        }
        
        final content = buffer.toString();
        
        // 检查内容长度是否符合要求
        if (content.length >= minLength) {
          // 检查连贯性问题
          if (attempts == 1 && content.contains("前文") || content.contains("上一章") || 
              content.contains("前面提到") || content.contains("之前") || 
              content.contains("如前所述") || content.contains("回顾") || 
              content.contains("正如我们所见")) {
            // 内容中含有明确的前文引用，可能连贯性良好
            
            // 确保章节内容被明确添加到对话历史中（虽然在流式生成时可能已经添加，但这里再次确认）
            if (conversationId != null) {
              String chapterTitle = chapterNumber != null ? "第${chapterNumber}章" : "新章节";
              print('将生成的章节内容"$chapterTitle"明确添加到对话历史中，对话ID: $conversationId');
              
              // 检查内容是否已在对话历史中存在
              bool contentExists = false;
              final messages = ConversationManager.getMessages(conversationId);
              for (final message in messages) {
                if (message['role'] == 'assistant' && 
                    message['content'].toString() == content) {
                  contentExists = true;
                  print('章节内容已存在于对话历史中，跳过添加');
                  break;
                }
              }
              
              // 如果内容不存在，则添加
              if (!contentExists) {
                ConversationManager.addMessage(conversationId, 'assistant', content);
                
                // 添加系统消息，提示下一章需要参考此章内容
                ConversationManager.addMessage(conversationId, 'system', 
                  "请在生成下一章节时，将上述章节内容作为前文参考，确保情节连贯，人物和世界观设定一致。");
                
                // 添加空的用户提示，准备接收下一章的指令
                ConversationManager.addMessage(conversationId, 'user', 
                  "这章写得很好，请记住这章的内容，为后续章节做准备。");
                  
                print('章节内容成功添加到对话历史中，当前对话历史长度: ${ConversationManager.getMessages(conversationId).length}');
              }
            }
            
            completer.complete(content);
            break;
          } else if (attempts < maxRetries) {
            // 尝试更强的连贯性要求
            print('尝试增强章节内容的连贯性 (尝试 $attempts/$maxRetries)');
            
            enhancedPrompt = '''
$basePrompt

【连贯性问题】
上次生成的内容与前文连贯性不足，请特别关注：
1. 明确引用前文中的具体事件和对话
2. 提及前文中角色说过的话语或做过的决定
3. 延续前文中未完成的事件和情节线
4. 确保角色的情感状态和动机与前文一致
5. 适当回顾前文中的重要转折点，并以此为基础向前推进情节

请重新创作，确保新内容是前文的自然延续，读者能够感受到整体故事的连贯性。
''';
            
            // 短暂延迟，避免API限速
            await Future.delayed(Duration(milliseconds: 500));
            continue;
          } else {
            // 最后一次尝试，返回现有内容
            // 确保章节内容被明确添加到对话历史中
            if (conversationId != null) {
              print('最后一次尝试，将生成的章节内容添加到对话历史中，对话ID: $conversationId');
              
              // 检查内容是否已在对话历史中存在
              bool contentExists = false;
              final messages = ConversationManager.getMessages(conversationId);
              for (final message in messages) {
                if (message['role'] == 'assistant' && 
                    message['content'].toString() == content) {
                  contentExists = true;
                  print('章节内容已存在于对话历史中，跳过添加');
                  break;
                }
              }
              
              // 如果内容不存在，则添加
              if (!contentExists) {
                ConversationManager.addMessage(conversationId, 'assistant', content);
                ConversationManager.addMessage(conversationId, 'system', 
                  "请在生成下一章节时，将上述章节内容作为前文参考，确保情节连贯。");
                print('章节内容成功添加到对话历史中');
              }
            }
            
            completer.complete(content);
            break;
          }
        } else {
          print('章节内容过短 (${content.length} < $minLength)，尝试重新生成 (尝试 $attempts/$maxRetries)');
          
          // 如果是最后一次尝试，返回已有内容而不是失败
          if (attempts >= maxRetries) {
            // 即使内容过短，也将其添加到对话历史中
            if (conversationId != null) {
              print('内容虽短但为最后尝试，将其添加到对话历史，对话ID: $conversationId');
              
              // 检查内容是否已在对话历史中存在
              bool contentExists = false;
              final messages = ConversationManager.getMessages(conversationId);
              for (final message in messages) {
                if (message['role'] == 'assistant' && 
                    message['content'].toString() == content) {
                  contentExists = true;
                  break;
                }
              }
              
              // 如果内容不存在，则添加
              if (!contentExists) {
                ConversationManager.addMessage(conversationId, 'assistant', content);
                print('短章节内容已添加到对话历史中');
              }
            }
            
            completer.complete(content);
            break;
          }
          
          // 增强提示词
          enhancedPrompt = '''$basePrompt
请提供更详细的章节内容，包含更多细节描写、人物对话和情节发展。上次生成的内容过于简短，需要扩展。请至少生成800字以上的完整章节。同时，确保与前文的连贯性，明确引用前文中的事件和人物特征。''';
          
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
    
    // 在方法结束前打印对话历史长度，用于调试
    if (conversationId != null) {
      final messagesCount = ConversationManager.getMessages(conversationId).length;
      print('generateChapterContent方法完成，当前对话历史消息数量: $messagesCount');
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

  // 使用大纲模型生成内容 - 简化参数，移除modelType相关代码
  Stream<String> generateOutlineTextStream({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
    String? conversationId,
    String? novelTitle,
  }) async* {
    final outlineModel = _apiConfig.getOutlineModel();
    
    // 如果提供了小说标题但没有提供对话ID，使用相同的对话ID系统
    if (novelTitle != null && conversationId == null) {
      conversationId = _getNovelConversationId(novelTitle);
      print('使用小说"$novelTitle"的对话ID: $conversationId');
    }
    
    yield* generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? outlineModel.temperature,
      topP: topP ?? outlineModel.topP,
      maxTokens: maxTokens ?? outlineModel.maxTokens,
      repetitionPenalty: repetitionPenalty ?? outlineModel.repetitionPenalty,
      specificModelConfig: outlineModel,
      conversationId: conversationId,
    );
  }

  // 使用章节模型生成内容 - 简化参数，移除modelType相关代码
  Stream<String> generateChapterTextStream({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
    String? conversationId,
    String? novelTitle,
  }) async* {
    final chapterModel = _apiConfig.getChapterModel();
    
    // 如果提供了小说标题但没有提供对话ID，使用相同的对话ID系统
    if (novelTitle != null && conversationId == null) {
      conversationId = _getNovelConversationId(novelTitle);
      print('使用小说"$novelTitle"的对话ID: $conversationId');
    }
    
    yield* generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? chapterModel.temperature,
      topP: topP ?? chapterModel.topP,
      maxTokens: maxTokens ?? chapterModel.maxTokens,
      repetitionPenalty: repetitionPenalty ?? chapterModel.repetitionPenalty,
      specificModelConfig: chapterModel,
      conversationId: conversationId,
    );
  }

  Future<String> generateOutline(String prompt, {String? novelTitle}) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 150; // 大纲最小长度限制
    String enhancedPrompt = prompt;
    
    // 获取或创建小说的对话ID
    String? conversationId;
    if (novelTitle != null) {
      conversationId = _getNovelConversationId(novelTitle);
      print('使用小说"$novelTitle"的对话ID: $conversationId');
      
      // 如果有对话ID，先清除可能存在的旧对话
      if (conversationId != null) {
        ConversationManager.clearConversation(conversationId);
        print('已清除旧的对话历史，确保大纲生成不受干扰');
      }
      
      // 初始化系统提示词
      if (conversationId != null) {
        ConversationManager.addMessage(conversationId, 'system', 
          "你是一个专业的小说大纲创作助手，请根据用户的需求提供完整的情节大纲。大纲要包含清晰的起承转合，角色线索和主要冲突。确保每个章节之间情节连贯，角色发展合理。请为每章节设计与整体情节结构相符的内容，避免逻辑断层和人物行动不一致。");
      }
    }
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        await for (final chunk in generateOutlineTextStream(
          systemPrompt: "你是一个专业的小说大纲创作助手，请根据用户的需求提供完整的情节大纲。大纲要包含清晰的起承转合，角色线索和主要冲突。确保每个章节之间情节连贯，角色发展合理。请为每章节设计与整体情节结构相符的内容，避免逻辑断层和人物行动不一致。",
          userPrompt: enhancedPrompt,
          temperature: 0.7,
          maxTokens: 2000,
          conversationId: conversationId, // 使用对话ID
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
        
        // 如果大纲生成成功，将其添加到对话历史中
        if (conversationId != null && content.length >= minLength) {
          print('将大纲添加到对话历史中，对话ID: $conversationId');
          
          // 确保大纲内容格式化良好
          String formattedOutline = content;
          if (!formattedOutline.contains('```')) {
            formattedOutline = "```\n" + formattedOutline + "\n```";
          }
          
          // 添加大纲内容作为助手的回复
          ConversationManager.addMessage(conversationId, 'assistant', 
            "我已经为这部小说创建了如下大纲:\n\n" + formattedOutline);
          
          // 添加用户的确认消息
          ConversationManager.addMessage(conversationId, 'user', 
            "非常好的大纲，请在后续章节创作中严格遵循这个大纲。");
            
          // 添加助手的确认消息  
          ConversationManager.addMessage(conversationId, 'assistant', 
            "我已经记住了这个大纲，后续章节创作将严格遵循这个框架。每个章节都会与大纲描述的内容相符，保持情节连贯性和角色一致性。");
          
          // 添加系统提示，指导后续章节生成
          ConversationManager.addMessage(conversationId, 'system', 
            "请在生成章节内容时严格参照上述大纲，确保内容与大纲一致，情节连贯。每个章节应与大纲中描述的内容相符。生成章节时，应该保持整体小说世界观和角色设定的一致性。");
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
    String? conversationId,
    String? novelTitle,
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 200; // 大纲最小长度限制
    
    // 如果提供了小说标题但没有提供对话ID，创建或获取对话ID
    if (novelTitle != null && conversationId == null) {
      conversationId = _getNovelConversationId(novelTitle);
      print('使用小说"$novelTitle"的对话ID: $conversationId');
    }
    
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
          systemPrompt: "你是一个专业的小说大纲创作助手，精通小说结构和故事发展。请根据用户需求提供连贯、合理的大纲。",
          userPrompt: enhancedPrompt,
          temperature: temperature ?? outlineModel.temperature,
          maxTokens: maxTokens ?? outlineModel.maxTokens,
          conversationId: conversationId,
          specificModelConfig: outlineModel,
        )) {
          buffer.write(chunk);
        }
        
        String content = buffer.toString();
        
        if (content.length < minLength) {
          if (attempts < maxRetries) {
            print('生成的大纲内容太短，尝试重新生成 (尝试 $attempts/$maxRetries)');
            enhancedPrompt = '''
${enhancedPrompt}

你的回答太简短了，请提供更详细的大纲内容，至少需要包含：
1. 更详细的情节发展描述
2. 主要角色的行动和动机
3. 每个部分的主要冲突和解决方式
4. 至少${minLength * 2}个字符的内容量
''';
            continue;
          }
        }
        
        // 如果大纲生成成功，将其添加到对话历史中
        if (conversationId != null && content.length >= minLength) {
          print('将智能大纲添加到对话历史中，对话ID: $conversationId');
          // 添加大纲内容作为助手的回复
          ConversationManager.addMessage(conversationId, 'assistant', 
            "我已经为这部小说创建了如下完整大纲:\n\n" + content);
          
          // 添加系统提示，指导后续章节生成
          ConversationManager.addMessage(conversationId, 'system', 
            "请在生成章节内容时严格参照上述大纲，确保内容与大纲一致，情节连贯。每个章节应与大纲中描述的内容相符，角色行为和发展应保持一致。");
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
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
    ModelConfig? specificModelConfig,
  }) async {
    final buffer = StringBuffer();
    
    await for (final chunk in generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      topP: topP ?? 1.0,
      maxTokens: maxTokens,
      repetitionPenalty: repetitionPenalty ?? 1.3,
      specificModelConfig: specificModelConfig,
    )) {
      buffer.write(chunk);
    }
    
    return buffer.toString();
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