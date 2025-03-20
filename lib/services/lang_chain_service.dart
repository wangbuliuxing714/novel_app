 import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/models/conversation_message.dart';

class LangChainService extends GetxService {
  final ApiConfigController _apiConfig;
  final Map<String, List<ConversationMessage>> _conversationHistory = {};
  
  // 设置会话历史记录的最大长度
  static const int maxConversationHistory = 20;

  LangChainService(this._apiConfig);

  // 初始化会话
  Future<void> initializeConversation(String sessionId, {String? systemPrompt}) async {
    if (!_conversationHistory.containsKey(sessionId)) {
      _conversationHistory[sessionId] = [];
    }
    
    // 添加系统提示作为第一条消息
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      _conversationHistory[sessionId]!.add(
        ConversationMessage(
          role: 'system',
          content: systemPrompt,
        ),
      );
    }
  }

  // 添加背景信息到会话
  Future<void> addBackgroundInfo(String sessionId, Map<String, dynamic> backgroundInfo) async {
    if (!_conversationHistory.containsKey(sessionId)) {
      throw Exception('会话未初始化');
    }

    final formattedBackground = _formatBackgroundInfo(backgroundInfo);
    
    // 将背景信息作为系统消息添加到历史记录
    _conversationHistory[sessionId]!.add(
      ConversationMessage(
        role: 'system',
        content: formattedBackground,
      ),
    );
  }

  // 生成内容
  Stream<String> generateContent(String sessionId, String prompt) async* {
    if (!_conversationHistory.containsKey(sessionId)) {
      throw Exception('会话未初始化');
    }
    
    // 添加用户输入到历史记录
    _conversationHistory[sessionId]!.add(
      ConversationMessage(
        role: 'user',
        content: prompt,
      ),
    );
    
    // 准备发送到API的消息
    final messages = _conversationHistory[sessionId]!.map((msg) => {
      'role': msg.role,
      'content': msg.content,
    }).toList();
    
    // 获取当前模型配置
    final config = _apiConfig.getCurrentModel();
    
    // 构建API请求体
    final body = jsonEncode({
      'model': config.model,
      'messages': messages,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'top_p': config.topP,
      'stream': true,
    });
    
    // 构建请求URL
    final url = Uri.parse('${config.apiUrl}${config.apiPath}');
    
    // 准备请求头
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': config.apiKey.startsWith('Bearer ') 
          ? config.apiKey 
          : 'Bearer ${config.apiKey}',
    };
    
    // 发送请求
    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers.addAll(headers);
      request.body = body;
      
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception('API请求失败: ${response.statusCode} - $errorBody');
      }
      
      String fullResponse = '';
      
      // 处理流式响应
      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          if (data == '[DONE]') continue;
          
          try {
            final json = jsonDecode(data);
            if (json['choices'] != null &&
                json['choices'][0]['delta'] != null &&
                json['choices'][0]['delta']['content'] != null) {
              final content = json['choices'][0]['delta']['content'] as String;
              fullResponse += content;
              yield content;
            }
          } catch (e) {
            print('Error parsing JSON: $e');
            continue;
          }
        }
      }
      
      // 添加AI响应到历史记录
      _conversationHistory[sessionId]!.add(
        ConversationMessage(
          role: 'assistant',
          content: fullResponse,
        ),
      );
      
      // 如果历史记录超过最大限制，移除最早的消息
      while (_conversationHistory[sessionId]!.length > maxConversationHistory) {
        _conversationHistory[sessionId]!.removeAt(0);
      }
    } finally {
      client.close();
    }
  }

  // 获取会话历史
  List<ConversationMessage> getConversationHistory(String sessionId) {
    return _conversationHistory[sessionId] ?? [];
  }

  // 清除会话
  void clearConversation(String sessionId) {
    _conversationHistory.remove(sessionId);
  }

  // 格式化背景信息
  String _formatBackgroundInfo(Map<String, dynamic> backgroundInfo) {
    final buffer = StringBuffer();
    buffer.writeln('背景信息：');
    
    backgroundInfo.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        buffer.writeln('$key: $value');
      }
    });
    
    return buffer.toString();
  }
}