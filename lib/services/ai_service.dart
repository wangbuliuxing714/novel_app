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

  // 添加临时配置变量
  String? _tempApiKey;
  String? _tempBaseUrl;
  String? _tempApiPath;
  String? _tempModel;
  String? _tempApiFormat;
  String? _tempAppId;

  AIService(this._apiConfig);

  // 添加更新配置的方法
  void updateConfig({
    String? apiKey,
    String? baseUrl,
    String? apiPath,
    String? model,
    String? apiFormat,
    String? appId,
  }) {
    _tempApiKey = apiKey;
    _tempBaseUrl = baseUrl;
    _tempApiPath = apiPath;
    _tempModel = model;
    _tempApiFormat = apiFormat;
    _tempAppId = appId;
  }

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
  }) async* {
    // 使用临时配置或默认配置
    final modelConfig = _apiConfig.getCurrentModel();
    final apiKey = _tempApiKey ?? modelConfig.apiKey;
    final apiUrl = _tempBaseUrl ?? modelConfig.apiUrl;
    final apiPath = _tempApiPath ?? modelConfig.apiPath;
    final model = _tempModel ?? modelConfig.model;
    final apiFormat = _tempApiFormat ?? modelConfig.apiFormat;
    final appId = _tempAppId ?? modelConfig.appId;

    // 清除临时配置
    _tempApiKey = null;
    _tempBaseUrl = null;
    _tempApiPath = null;
    _tempModel = null;
    _tempApiFormat = null;
    _tempAppId = null;

    if (apiKey.isEmpty) {
      throw Exception('API Key not set');
    }

    final client = http.Client();
    final uri = Uri.parse('$apiUrl$apiPath');

    try {
      final Map<String, dynamic> body = apiFormat == 'Google API'
          ? {
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
                'maxOutputTokens': maxTokens,
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
            }
          : {
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

      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (apiFormat == 'Google API') {
        headers['x-goog-api-key'] = apiKey;
      } else if (appId.isNotEmpty) {
        headers['X-Bce-Authorization'] = apiKey;
        headers['X-Appid'] = appId;
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final request = http.Request('POST', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception('API request failed with status ${streamedResponse.statusCode}: $errorBody');
      }

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        if (chunk.trim().isEmpty) continue;

        if (apiFormat == 'Google API') {
          final data = jsonDecode(chunk);
          if (data['candidates'] != null &&
              data['candidates'][0]['content'] != null &&
              data['candidates'][0]['content']['parts'] != null &&
              data['candidates'][0]['content']['parts'][0]['text'] != null) {
            yield data['candidates'][0]['content']['parts'][0]['text'];
          }
        } else {
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
                print('Error parsing JSON: $e');
                continue;
              }
            }
          }
        }
      }
    } finally {
      client.close();
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
    final completer = Completer<String>();
    final buffer = StringBuffer();
    
    try {
      await for (final chunk in generateTextStream(
        systemPrompt: prompt,
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
      await for (final chunk in generateTextStream(
        systemPrompt: prompt,
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
      await for (final chunk in generateTextStream(
        systemPrompt: prompt,
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