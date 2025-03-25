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
import 'package:uuid/uuid.dart';

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
  
  // 防止重复请求的静态映射表
  static final Map<String, int> _processingChapterRequests = {};
  static final Map<String, int> _processingOutlineRequests = {};
  static final Map<String, int> _processingRequests = {};
  
  AIService(this._apiConfig);

  // 添加一个方法来获取小说的基础ID（大纲和章节共用同一个基础ID）
  String _getNovelBaseId(String novelTitle) {
    return '_novel_${novelTitle.replaceAll(' ', '_')}';
  }
  
  // 获取小说大纲的会话ID
  String _getNovelOutlineId(String novelTitle) {
    String baseId = _getNovelBaseId(novelTitle);
    return '${baseId}_outline';
  }
  
  // 获取小说章节的会话ID
  String _getNovelChapterId(String novelTitle, int chapterNumber) {
    String baseId = _getNovelBaseId(novelTitle);
    return '${baseId}_chapter_$chapterNumber';
  }

  // 获取或创建小说的对话ID - 简化回最初版本
  String _getNovelConversationId(String novelTitle) {
    // 优先使用一致的命名模式，提高历史记录的可追踪性
    final standardId = '_outline_${novelTitle.replaceAll(' ', '_')}';
    
    // 首先检查是否使用标准ID已存在
    if (_novelConversationIds.containsKey(standardId)) {
      print('找到预先创建的标准对话ID: $standardId');
      return _novelConversationIds[standardId]!;
    }
    
    // 然后检查是否使用小说标题作为键已存在
    if (_novelConversationIds.containsKey(novelTitle)) {
      final existingId = _novelConversationIds[novelTitle]!;
      print('找到现有小说对话ID: $existingId (对应标题: $novelTitle)');
      
      // 将旧标题对应的ID迁移到新的标准ID格式下
      _novelConversationIds[standardId] = existingId;
      print('已将对话ID迁移到标准格式: $standardId -> $existingId');
      
      return existingId;
    }
    
    // 如果不存在，创建新的对话ID并同时用标准格式和原始标题进行存储
    final newId = ConversationManager.createConversation();
    _novelConversationIds[novelTitle] = newId;
    _novelConversationIds[standardId] = newId;
    
    print('为小说创建新对话ID:');
    print('- 标题: "$novelTitle"');
    print('- 标准化ID: "$standardId"');
    print('- 对话ID: "$newId"');
    print('此ID将用于保存所有与该小说相关的对话历史，确保章节间的内容连贯性');
    
    return newId;
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
        
        // 获取章节专用模型配置
        final chapterModelConfig = Get.find<ApiConfigController>().getChapterModel();
        print('内容生成使用章节专用模型: ${chapterModelConfig.name}');
        
        await for (final chunk in generateTextStream(
          systemPrompt: "你是一个专业的小说创作助手，请根据用户的要求提供高质量的内容。请用非常简洁的描述方式描述剧情，冲突部分可以详细描写，快节奏，多对话形式，以小见大，人物对话格式：'xxxxx'某某说道。严禁使用任何形式的小标题、序号或章节编号。严禁使用情节点、转折点、高潮点等标题或分段标记。严禁使用总结性语言，如\"总之\"、\"总的来说\"、\"简而言之\"等。严禁添加旁白或解说，严禁添加\"作者注\"、\"编者按\"等内容。直接用流畅的叙述展开故事，只关注推动情节发展的内容。内容字数必须不少于3000字，字数一定要达到3000字，确保内容充分展开。",
          userPrompt: enhancedPrompt,
          temperature: 0.7,
          maxTokens: 7000,
          specificModelConfig: chapterModelConfig,
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
    
    // 如果提供了conversationId，则使用对话历史，否则直接使用系统提示词和用户提示词
    List<Map<String, dynamic>> messages = [];
    if (conversationId != null) {
      // 使用已有的对话历史
      messages = ConversationManager.getMessages(conversationId);
      
      // 增强打印对话历史，帮助调试
      print('===== 对话历史详情 (ID: $conversationId) =====');
      print('对话历史条数: ${messages.length}');
      
      // 打印系统消息
      print('系统消息:');
      int systemMsgCount = 0;
      for (var msg in messages) {
        if (msg['role'] == 'system') {
          systemMsgCount++;
          print('  [$systemMsgCount] ${(msg['content'] as String).length > 100 ? (msg['content'] as String).substring(0, 100) + "..." : msg['content']}');
        }
      }
      
      // 打印用户消息和助手消息对
      print('对话流:');
      int msgPairCount = 0;
      for (var i = 0; i < messages.length; i++) {
        if (messages[i]['role'] == 'user') {
          msgPairCount++;
          print('  - 对话对[$msgPairCount]:');
          print('    * 用户: ${(messages[i]['content'] as String).length > 100 ? (messages[i]['content'] as String).substring(0, 100) + "..." : messages[i]['content']}');
          
          // 查找这条用户消息后的助手回复
          if (i+1 < messages.length && messages[i+1]['role'] == 'assistant') {
            print('    * 助手: ${(messages[i+1]['content'] as String).length > 100 ? (messages[i+1]['content'] as String).substring(0, 100) + "..." : messages[i+1]['content']}');
          } else {
            print('    * 助手: [未找到对应回复]');
          }
        }
      }
      
      // 检查对话历史中是否有大纲内容
      bool hasOutline = false;
      for (final msg in messages) {
        if (msg['role'] == 'assistant' && 
            (msg['content'] as String).contains('大纲') && 
            (msg['content'] as String).length > 100) {
          hasOutline = true;
          print('对话历史中包含大纲内容 ✓');
          break;
        }
      }
      
      if (!hasOutline) {
        print('警告: 对话历史中不包含大纲内容 ✗');
      }
      
      // 如果对话历史为空，添加系统提示词
      if (messages.isEmpty) {
        print('对话历史为空，添加系统提示词');
        messages.add({
          'role': 'system',
          'content': systemPrompt
        });
      }
      
      // 检查用户提示是否已经存在
      bool promptExists = false;
      for (final msg in messages) {
        if (msg['role'] == 'user' && msg['content'] == userPrompt) {
          promptExists = true;
          print('用户提示已存在于对话历史中，避免重复添加');
          break;
        }
      }
      
      // 仅当提示不存在时添加
      if (!promptExists) {
        print('添加新的用户提示到对话历史');
        messages.add({
          'role': 'user',
          'content': userPrompt
        });
        
        // 更新对话历史
        ConversationManager.addMessage(conversationId, 'user', userPrompt);
      } else {
        // 如果提示已存在，不需要重新添加到对话历史
        print('跳过重复添加用户提示到对话历史');
      }
    } else {
      // 使用单次对话模式
      print('使用单次对话模式，没有对话历史');
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
            'max_tokens': maxTokens != null ? (maxTokens > 8192 ? 8192 : maxTokens) : 4000,
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
            'max_tokens': maxTokens > 8192 ? 8192 : maxTokens,
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
          'max_tokens': maxTokens > 8192 ? 8192 : maxTokens,
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

  // 修改章节生成方法，使用与大纲相关联的ID
  Future<String> generateChapterContent(
    String basePrompt, {
    int? chapterNumber,
    String? outlineContent,
    String? conversationId,
    String? novelTitle,
    int minLength = 800,
    int maxRetries = 3,
    void Function(String)? onProgress,
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    
    // 确保有小说标题
    if (novelTitle == null || novelTitle.isEmpty) {
      novelTitle = "未命名小说_${DateTime.now().millisecondsSinceEpoch}";
    }
    
    // 生成一个固定的会话ID，确保同一小说章节使用相同ID
    if (novelTitle != null && chapterNumber != null && conversationId == null) {
      conversationId = _getNovelChapterId(novelTitle, chapterNumber);
      print('为章节生成固定ID: $conversationId');
    }
    
    // 键是novelTitle+chapterNumber，值是处理时间戳
    String requestKey = '${novelTitle ?? "unknown"}_${chapterNumber ?? 0}';
    
    // 检查是否在5秒内处理过相同的请求
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (_processingChapterRequests.containsKey(requestKey)) {
      int lastProcessTime = _processingChapterRequests[requestKey]!;
      if (currentTime - lastProcessTime < 5000) { // 5秒内的重复请求
        print('检测到5秒内的重复章节生成请求，跳过处理');
        // 尝试从历史中获取最近的结果
        if (conversationId != null) {
          final messages = ConversationManager.getMessages(conversationId);
          for (var i = messages.length - 1; i >= 0; i--) {
            if (messages[i]['role'] == 'assistant' && (messages[i]['content'] as String).length > minLength) {
              print('返回历史中的章节内容');
              return messages[i]['content'] as String;
            }
          }
        }
      }
    }
    
    // 记录当前请求时间戳
    _processingChapterRequests[requestKey] = currentTime;
    
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
4. 请直接开始撰写章节内容，不要添加任何前导说明
5. 请用非常简洁的描述方式描述剧情，冲突部分可以详细描写
6. 快节奏，多对话形式，以小见大
7. 人物对话格式：'xxxxx'某某说道
8. 严禁使用任何形式的小标题、序号或章节编号
9. 严禁使用情节点、转折点、高潮点等标题或分段标记
10. 严禁使用总结性语言，如\"总之\"、\"总的来说\"、\"简而言之\"等
11. 严禁添加旁白或解说，严禁添加\"作者注\"、\"编者按\"等内容
12. 直接用流畅的叙述展开故事，只关注推动情节发展的内容
13. 必须保持与前面章节的情节连续性，包括时间线、人物状态和关系发展，确保读者感受到自然的故事进展
14. 章节字数必须不少于3000字
''';
    }
    
    // 如果提供了对话ID和系统提示，确保对话历史中有系统提示
    if (conversationId != null) {
      final messages = ConversationManager.getMessages(conversationId);
      bool hasSystemMessage = false;
      
      // 检查是否已有系统提示
      for (var msg in messages) {
        if (msg['role'] == 'system') {
          hasSystemMessage = true;
          break;
        }
      }
      
      // 如果没有系统提示，添加一个
      if (!hasSystemMessage) {
        ConversationManager.addMessage(conversationId, 'system', 
          "你是一个专业的小说章节创作助手，请根据用户的需求提供高质量、有代入感的章节内容。请用非常简洁的描述方式描述剧情，冲突部分可以详细描写，快节奏，多对话形式，以小见大，人物对话格式：'xxxxx'某某说道。严禁使用任何形式的小标题、序号或章节编号。严禁使用情节点、转折点、高潮点等标题或分段标记。严禁使用总结性语言，如\"总之\"、\"总的来说\"、\"简而言之\"等。严禁添加旁白或解说，严禁添加\"作者注\"、\"编者按\"等内容。直接用流畅的叙述展开故事，只关注推动情节发展的内容。必须保持与前面章节的情节连续性，包括时间线、人物状态和关系发展，确保读者感受到自然的故事进展。每章必须至少3000字，字数一定要达到3000字，确保内容充分展开。");
        print('为对话添加系统提示');
      }
      
      // 添加用户提示
      ConversationManager.addMessage(conversationId, 'user', basePrompt);
      print('添加用户提示到对话');
    }
    
    // 需要重试的函数
    Future<void> attemptGeneration() async {
      try {
        final startTime = DateTime.now();
        
        print('开始使用对话ID生成章节内容: $conversationId');
        
        // 获取章节专用模型配置
        final chapterModelConfig = Get.find<ApiConfigController>().getChapterModel();
        print('使用章节专用模型: ${chapterModelConfig.name}');
        
        await for (final chunk in generateTextStream(
          systemPrompt: "你是一个专业的小说章节创作助手，请根据用户的需求提供高质量、有代入感的章节内容。请用非常简洁的描述方式描述剧情，冲突部分可以详细描写，快节奏，多对话形式，以小见大，人物对话格式：'xxxxx'某某说道。严禁使用任何形式的小标题、序号或章节编号。严禁使用情节点、转折点、高潮点等标题或分段标记。严禁使用总结性语言，如\"总之\"、\"总的来说\"、\"简而言之\"等。严禁添加旁白或解说，严禁添加\"作者注\"、\"编者按\"等内容。直接用流畅的叙述展开故事，只关注推动情节发展的内容。必须保持与前面章节的情节连续性，包括时间线、人物状态和关系发展，确保读者感受到自然的故事进展。每章必须至少3000字，字数一定要达到3000字，确保内容充分展开。",
          userPrompt: basePrompt,
          temperature: 0.8,
          maxTokens: 7000,
          conversationId: conversationId,
          specificModelConfig: chapterModelConfig
        )) {
          buffer.write(chunk);
          onProgress?.call(chunk);
        }
        
        final duration = DateTime.now().difference(startTime);
        print('章节内容生成完成，用时: ${duration.inSeconds}秒，长度: ${buffer.length}字符');
        
        // 如果章节内容太短，可能生成不完整，需要重试
        if (buffer.length < minLength && attempts < maxRetries) {
          print('生成的内容过短 (${buffer.length} 字符 < $minLength)，尝试重新生成 (尝试 ${attempts + 1}/$maxRetries)');
          buffer.clear();
          attempts++;
          await attemptGeneration();
          return;
        }
        
        var result = buffer.toString();
        
        // 将生成的内容添加到会话历史中
        if (conversationId != null) {
          ConversationManager.addMessage(conversationId, 'assistant', result);
          print('已将生成的章节内容添加到会话历史中 (长度: ${result.length}字符)');
        }
        
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e) {
        print('生成章节内容时出错: $e');
        if (attempts < maxRetries) {
          print('尝试重新生成 (尝试 ${attempts + 1}/$maxRetries)');
          buffer.clear();
          attempts++;
          await attemptGeneration();
        } else {
          if (!completer.isCompleted) {
            completer.completeError('生成章节内容失败，已达到最大重试次数: $e');
          }
        }
      }
    }
    
    await attemptGeneration();
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
      
      // 获取章节专用模型配置
      final chapterModelConfig = Get.find<ApiConfigController>().getChapterModel();
      print('短篇小说生成使用章节专用模型: ${chapterModelConfig.name}');
      
      await for (final chunk in generateContentStream(
        systemPrompt: finalPrompt + "\n\n创作要求：请用非常简洁的描述方式描述剧情，冲突部分可以详细描写，快节奏，多对话形式，以小见大，人物对话格式：'xxxxx'某某说道。严禁使用任何形式的小标题、序号或章节编号。严禁使用情节点、转折点、高潮点等标题或分段标记。严禁使用总结性语言，如\"总之\"、\"总的来说\"、\"简而言之\"等。严禁添加旁白或解说，严禁添加\"作者注\"、\"编者按\"等内容。直接用流畅的叙述展开故事，只关注推动情节发展的内容。内容字数必须不少于3000字，字数一定要达到3000字，确保内容充分展开。",
        userPrompt: "请根据以上要求创作一篇高质量的短篇小说内容",
        temperature: 0.78, // 提高创造性
        maxTokens: 7500, // 最大token上限
        repetitionPenalty: 1.0, // 不进行重复惩罚，允许更自然的文学表达
        topP: 0.95, // 提高多样性
        specificModelConfig: chapterModelConfig,
      )) {
        buffer.write(chunk);
      }
      
      completer.complete(buffer.toString());
    } catch (e) {
      completer.completeError('生成短篇小说内容失败: $e');
    }
    
    return completer.future;
  }

  // 使用大纲模型生成内容 - 简化参数
  Stream<String> generateOutlineTextStream({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
    String? conversationId,
    String? novelTitle,
    ModelConfig? specificModelConfig,
  }) async* {
    // 如果提供了小说标题但没有提供对话ID，使用小说特定的对话ID系统
    if (novelTitle != null && conversationId == null) {
      conversationId = _getNovelOutlineId(novelTitle);
      print('使用小说特定大纲对话ID: $conversationId');
    }
    
    // 获取大纲模型配置（如果未指定）
    if (specificModelConfig == null) {
      // 从ApiConfigController获取大纲模型配置
      specificModelConfig = Get.find<ApiConfigController>().getOutlineModel();
      print('使用大纲专用模型: ${specificModelConfig.name}');
    }
    
    // 使用通用的生成文本流方法，传递大纲专用模型
    yield* generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? 0.7,
      topP: topP ?? 1.0,
      maxTokens: maxTokens ?? 2000,
      repetitionPenalty: repetitionPenalty ?? 1.3,
      conversationId: conversationId,
      specificModelConfig: specificModelConfig,
    );
  }

  // 用于短篇小说内容生成的流式方法
  Stream<String> generateContentStream({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty,
    String? conversationId,
    ModelConfig? specificModelConfig,
  }) async* {
    // 使用通用的生成文本流方法
    yield* generateTextStream(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? 0.75,
      topP: topP ?? 0.95,
      maxTokens: maxTokens ?? 7000,
      repetitionPenalty: repetitionPenalty ?? 1.0,
      conversationId: conversationId,
      specificModelConfig: specificModelConfig,
    );
  }

  // 修改生成大纲的方法，使用与章节相关联的ID
  Future<String> generateOutline(String prompt, {String? novelTitle}) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    int attempts = 0;
    final int maxRetries = 3;
    final int minLength = 150; // 大纲最小长度限制
    
    // 确保有小说标题
    if (novelTitle == null || novelTitle.isEmpty) {
      novelTitle = "未命名小说_${DateTime.now().millisecondsSinceEpoch}";
    }
    
    // 使用小说特定的大纲ID
    String conversationId = _getNovelOutlineId(novelTitle);
    print('使用小说特定大纲ID: $conversationId');
    
    String requestKey = '${novelTitle}_outline';
    
    // 检查是否在3秒内处理过相同的请求
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (_processingRequests.containsKey(requestKey)) {
      int lastProcessTime = _processingRequests[requestKey]!;
      if (currentTime - lastProcessTime < 3000) { // 3秒内的重复请求
        print('检测到3秒内的重复大纲生成请求，跳过处理');
        // 尝试从历史中获取最近的结果
        final messages = ConversationManager.getMessages(conversationId);
        for (var i = messages.length - 1; i >= 0; i--) {
          if (messages[i]['role'] == 'assistant' && (messages[i]['content'] as String).length > minLength) {
            print('返回历史中的大纲内容');
            return messages[i]['content'] as String;
          }
        }
      }
    }
    
    // 记录当前请求时间戳
    _processingRequests[requestKey] = currentTime;
    
    try {
      // 初始化系统提示词
      // 检查是否已有系统提示
      final messages = ConversationManager.getMessages(conversationId);
      bool hasSystemMessage = false;
      for (var msg in messages) {
        if (msg['role'] == 'system') {
          hasSystemMessage = true;
          break;
        }
      }
      
      if (!hasSystemMessage) {
        ConversationManager.addMessage(conversationId, 'system', 
          "你是一个专业的小说大纲创作助手，请根据用户的需求提供完整的情节大纲。大纲要包含清晰的起承转合，角色线索和主要冲突。确保每个章节之间情节连贯，角色发展合理。请为每章节设计与整体情节结构相符的内容，避免逻辑断层和人物行动不一致。特别强调情节的连续性和一致性，确保时间线、人物状态和关系发展始终保持清晰和合理。");
        print('为小说特定对话添加系统提示');
      }
      
      // 添加用户提示
      ConversationManager.addMessage(conversationId, 'user', prompt);
      print('向小说特定对话添加用户提示');
      
      // 尝试生成，允许重试
      while (attempts < maxRetries) {
        attempts++;
        buffer.clear(); // 清空之前的内容
        
        print('开始生成大纲，尝试次数: $attempts');
        
        // 获取大纲专用模型配置
        final outlineModelConfig = Get.find<ApiConfigController>().getOutlineModel();
        print('使用大纲专用模型: ${outlineModelConfig.name}');
        
        await for (final chunk in generateOutlineTextStream(
          systemPrompt: "你是一个专业的小说大纲创作助手，请根据用户的需求提供完整的情节大纲。大纲要包含清晰的起承转合，角色线索和主要冲突。确保每个章节之间情节连贯，角色发展合理。请为每章节设计与整体情节结构相符的内容，避免逻辑断层和人物行动不一致。",
          userPrompt: prompt,
          temperature: 0.7,
          maxTokens: 2000,
          conversationId: conversationId, // 使用小说特定对话ID
          novelTitle: novelTitle
        )) {
          buffer.write(chunk);
        }
        
        String content = buffer.toString();
        
        if (content.length < minLength && attempts < maxRetries) {
          print('生成的内容过短 (${content.length} 字符 < $minLength)，尝试重新生成...');
          continue;
        }
        
        // 将AI的回复添加到对话历史
        ConversationManager.addMessage(conversationId, 'assistant', content);
        
        // 添加系统提示，指导后续章节生成
        ConversationManager.addMessage(conversationId, 'system', 
          "请在生成章节内容时严格参照上述大纲，确保内容与大纲一致，情节连贯。每个章节应与大纲中描述的内容相符。生成章节时，应该保持整体小说世界观和角色设定的一致性。必须确保前后章节的时间线连贯，人物状态和情感发展连续，关系变化合理，让读者能感受到自然流畅的故事进展。请用非常简洁的描述方式描述剧情，冲突部分可以详细描写，快节奏，多对话形式，以小见大，人物对话格式：'xxxxx'某某说道。严禁使用任何形式的小标题、序号或章节编号。严禁使用情节点、转折点、高潮点等标题或分段标记。严禁使用总结性语言，如\"总之\"、\"总的来说\"、\"简而言之\"等。严禁添加旁白或解说，严禁添加\"作者注\"、\"编者按\"等内容。直接用流畅的叙述展开故事，只关注推动情节发展的内容。每章必须至少3000字，字数一定要达到3000字，确保内容充分展开。");
        
        // 将大纲内容保存到小说的基本会话ID中，使章节生成时可以访问
        String baseId = _getNovelBaseId(novelTitle);
        ConversationManager.addMessage(baseId, 'system', "小说《$novelTitle》的大纲");
        ConversationManager.addMessage(baseId, 'user', "请创建小说大纲");
        ConversationManager.addMessage(baseId, 'assistant', content);
        print('已将大纲内容保存到小说基础ID: $baseId');
        
        return content;
      }
      
      // 如果重试后仍然过短，直接返回
      return buffer.toString();
    } catch (e) {
      print('生成大纲时出错: $e');
      throw e;
    }
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