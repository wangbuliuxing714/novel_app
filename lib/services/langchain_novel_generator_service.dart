import 'package:get/get.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/prompts/master_prompts.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'dart:convert';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'dart:math';

// LangChain风格的消息类
class ChatMessage {
  final String role; // system, user, assistant
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// 聊天历史管理类
class ChatHistory {
  final String sessionId;
  final List<ChatMessage> messages;
  final int maxContextLength;
  final int maxMessages;

  ChatHistory({
    String? sessionId,
    List<ChatMessage>? messages,
    this.maxContextLength = 16000,
    this.maxMessages = 50,
  }) : 
    sessionId = sessionId ?? const Uuid().v4(),
    messages = messages ?? [];

  // 添加消息
  void addMessage(ChatMessage message) {
    messages.add(message);
    // 如果消息太多，移除最旧的消息
    if (messages.length > maxMessages) {
      messages.removeAt(0);
    }
  }

  // 获取格式化的上下文
  String getFormattedContext() {
    int totalLength = 0;
    final formattedMessages = <String>[];
    
    // 从最新的消息开始，直到填满上下文窗口
    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      final formattedMessage = '${message.role}: ${message.content}';
      
      totalLength += formattedMessage.length;
      if (totalLength > maxContextLength) {
        break;
      }
      
      formattedMessages.insert(0, formattedMessage);
    }
    
    return formattedMessages.join('\n\n');
  }

  // 获取原始消息列表用于API调用
  List<Map<String, String>> getAPIMessages() {
    return messages.map((msg) => {
      'role': msg.role,
      'content': msg.content,
    }).toList();
  }

  // 清空历史
  void clear() {
    messages.clear();
  }

  // 转换为JSON
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'messages': messages.map((m) => m.toJson()).toList(),
    'maxContextLength': maxContextLength,
    'maxMessages': maxMessages,
  };

  // 从JSON创建
  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    return ChatHistory(
      sessionId: json['sessionId'],
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
      maxContextLength: json['maxContextLength'] ?? 16000,
      maxMessages: json['maxMessages'] ?? 50,
    );
  }
}

// 小说背景信息类
class NovelContext {
  final String title;
  final String genre;
  final String plotOutline;
  final Map<String, dynamic> characters;
  final Map<String, dynamic> worldBuilding;
  final String style;
  final String tone;

  NovelContext({
    required this.title,
    required this.genre,
    required this.plotOutline,
    this.characters = const {},
    this.worldBuilding = const {},
    this.style = '',
    this.tone = '',
  });

  String getFormattedContext() {
    final buffer = StringBuffer();
    
    buffer.writeln('# 小说信息');
    buffer.writeln('标题: $title');
    buffer.writeln('类型: $genre');
    
    if (style.isNotEmpty) {
      buffer.writeln('风格: $style');
    }
    
    if (tone.isNotEmpty) {
      buffer.writeln('基调: $tone');
    }
    
    buffer.writeln('\n# 情节大纲');
    buffer.writeln(plotOutline);
    
    if (characters.isNotEmpty) {
      buffer.writeln('\n# 角色信息');
      characters.forEach((name, info) {
        buffer.writeln('- $name: ${json.encode(info)}');
      });
    }
    
    if (worldBuilding.isNotEmpty) {
      buffer.writeln('\n# 世界观设定');
      worldBuilding.forEach((aspect, detail) {
        buffer.writeln('- $aspect: $detail');
      });
    }
    
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'genre': genre,
    'plotOutline': plotOutline,
    'characters': characters,
    'worldBuilding': worldBuilding,
    'style': style,
    'tone': tone,
  };

  factory NovelContext.fromJson(Map<String, dynamic> json) {
    return NovelContext(
      title: json['title'],
      genre: json['genre'],
      plotOutline: json['plotOutline'],
      characters: json['characters'] ?? {},
      worldBuilding: json['worldBuilding'] ?? {},
      style: json['style'] ?? '',
      tone: json['tone'] ?? '',
    );
  }
}

class LangchainNovelGeneratorService extends GetxService {
  final AIService _aiService;
  final ApiConfigController _apiConfig;
  final CacheService _cacheService;
  
  // 会话管理
  final Map<String, ChatHistory> _activeSessions = {};
  final Map<String, NovelContext> _sessionContexts = {};
  
  // 响应式状态
  final RxMap<String, bool> _generatingStatus = <String, bool>{}.obs;
  final RxMap<String, String> _lastError = <String, String>{}.obs;

  LangchainNovelGeneratorService(
    this._aiService, 
    this._cacheService, 
    this._apiConfig,
  );

  // 创建新的小说会话
  String createNovelSession({
    required String title,
    required String genre,
    required String plotOutline,
    Map<String, dynamic> characters = const {},
    Map<String, dynamic> worldBuilding = const {},
    String style = '',
    String tone = '',
  }) {
    final sessionId = const Uuid().v4();
    final context = NovelContext(
      title: title,
      genre: genre,
      plotOutline: plotOutline,
      characters: characters,
      worldBuilding: worldBuilding,
      style: style,
      tone: tone,
    );
    
    // 创建会话历史
    final history = ChatHistory(sessionId: sessionId);
    
    // 添加系统消息
    history.addMessage(ChatMessage(
      role: 'system',
      content: buildSystemPrompt(context),
    ));
    
    // 添加初始化消息
    history.addMessage(ChatMessage(
      role: 'assistant',
      content: '我已经准备好了，请告诉我您想如何开始这个故事？',
    ));
    
    // 保存会话
    _activeSessions[sessionId] = history;
    _sessionContexts[sessionId] = context;
    _generatingStatus[sessionId] = false;
    
    // 保存会话到缓存
    _saveChatSession(sessionId);
    
    return sessionId;
  }

  // 获取会话列表
  List<Map<String, dynamic>> getNovelSessions() {
    return _activeSessions.entries.map((entry) {
      final context = _sessionContexts[entry.key];
      return {
        'sessionId': entry.key,
        'title': context?.title ?? '未命名小说',
        'genre': context?.genre ?? '未知类型',
        'messageCount': entry.value.messages.length,
        'lastModified': entry.value.messages.isNotEmpty 
            ? entry.value.messages.last.timestamp 
            : DateTime.now(),
      };
    }).toList();
  }

  // 获取特定会话
  ChatHistory? getSession(String sessionId) {
    return _activeSessions[sessionId];
  }

  // 获取特定会话的上下文
  NovelContext? getSessionContext(String sessionId) {
    return _sessionContexts[sessionId];
  }

  // 删除会话
  Future<void> deleteSession(String sessionId) async {
    _activeSessions.remove(sessionId);
    _sessionContexts.remove(sessionId);
    _generatingStatus.remove(sessionId);
    _lastError.remove(sessionId);
    
    // 从缓存中删除
    final chatBox = await _cacheService.openChatSessionBox();
    await chatBox.delete(sessionId);
    
    final contextBox = await _cacheService.openChatContextBox();
    await contextBox.delete(sessionId);
  }

  // 生成小说内容流
  Stream<String> generateNovelStream({
    required String sessionId,
    required String userMessage,
    double temperature = 0.7,
  }) async* {
    // 检查会话是否存在
    if (!_activeSessions.containsKey(sessionId)) {
      throw Exception('会话不存在');
    }
    
    // 设置生成状态
    _generatingStatus[sessionId] = true;
    
    try {
      final history = _activeSessions[sessionId]!;
      
      // 添加用户消息
      history.addMessage(ChatMessage(
        role: 'user',
        content: userMessage,
      ));
      
      // 构建回复内容
      final StringBuffer responseBuffer = StringBuffer();
      
      // 使用AI服务生成回复
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: buildSystemPrompt(_sessionContexts[sessionId]!),
        userPrompt: userMessage,
        temperature: temperature,
        maxTokens: _apiConfig.getCurrentModel().maxTokens,
      )) {
        responseBuffer.write(chunk);
        yield chunk;
      }
      
      // 完成后，将回复添加到历史
      final responseContent = responseBuffer.toString();
      history.addMessage(ChatMessage(
        role: 'assistant',
        content: responseContent,
      ));
      
      // 保存会话
      _saveChatSession(sessionId);
      
    } catch (e) {
      _lastError[sessionId] = e.toString();
      throw Exception('生成内容失败: $e');
    } finally {
      _generatingStatus[sessionId] = false;
    }
  }

  // 生成小说内容（非流式）
  Future<String> generateNovelContent({
    required String sessionId,
    required String userMessage,
    double temperature = 0.7,
  }) async {
    // 检查会话是否存在
    if (!_activeSessions.containsKey(sessionId)) {
      throw Exception('会话不存在');
    }
    
    // 设置生成状态
    _generatingStatus[sessionId] = true;
    
    try {
      final history = _activeSessions[sessionId]!;
      
      // 添加用户消息
      history.addMessage(ChatMessage(
        role: 'user',
        content: userMessage,
      ));
      
      // 生成回复
      final response = await _aiService.generateText(
        systemPrompt: buildSystemPrompt(_sessionContexts[sessionId]!),
        userPrompt: userMessage,
        temperature: temperature,
        maxTokens: _apiConfig.getCurrentModel().maxTokens,
      );
      
      // 将回复添加到历史
      history.addMessage(ChatMessage(
        role: 'assistant',
        content: response,
      ));
      
      // 保存会话
      _saveChatSession(sessionId);
      
      return response;
    } catch (e) {
      _lastError[sessionId] = e.toString();
      throw Exception('生成内容失败: $e');
    } finally {
      _generatingStatus[sessionId] = false;
    }
  }

  // 导出小说
  Future<Novel> exportNovel(String sessionId) async {
    // 检查会话是否存在
    if (!_activeSessions.containsKey(sessionId)) {
      throw Exception('会话不存在');
    }
    
    final history = _activeSessions[sessionId]!;
    final context = _sessionContexts[sessionId]!;
    
    // 只获取助手的消息
    final assistantMessages = history.messages
        .where((msg) => msg.role == 'assistant')
        .map((msg) => msg.content)
        .toList();
    
    // 合并内容
    final content = assistantMessages.join('\n\n');
    
    // 创建章节
    final chapter = Chapter(
      number: 1,
      title: context.title,
      content: content,
    );
    
    // 创建小说
    return Novel(
      title: context.title,
      genre: context.genre,
      outline: context.plotOutline,
      content: content,
      chapters: [chapter],
      createdAt: DateTime.now(),
    );
  }

  // 加载会话
  Future<void> loadChatSessions() async {
    try {
      final chatBox = await _cacheService.openChatSessionBox();
      final contextBox = await _cacheService.openChatContextBox();
      
      final keys = chatBox.keys.toList();
      for (final key in keys) {
        final chatJsonStr = chatBox.get(key);
        final contextJsonStr = contextBox.get(key);
        
        if (chatJsonStr != null && contextJsonStr != null) {
          try {
            final chatJson = json.decode(chatJsonStr);
            final contextJson = json.decode(contextJsonStr);
            
            _activeSessions[key.toString()] = ChatHistory.fromJson(chatJson);
            _sessionContexts[key.toString()] = NovelContext.fromJson(contextJson);
            _generatingStatus[key.toString()] = false;
          } catch (e) {
            print('解析会话数据失败: $e');
          }
        }
      }
    } catch (e) {
      print('加载会话失败: $e');
    }
  }

  // 保存会话
  Future<void> _saveChatSession(String sessionId) async {
    try {
      final chatBox = await _cacheService.openChatSessionBox();
      final contextBox = await _cacheService.openChatContextBox();
      
      final chatHistory = _activeSessions[sessionId];
      final novelContext = _sessionContexts[sessionId];
      
      if (chatHistory != null && novelContext != null) {
        await chatBox.put(sessionId, json.encode(chatHistory.toJson()));
        await contextBox.put(sessionId, json.encode(novelContext.toJson()));
      }
    } catch (e) {
      print('保存会话失败: $e');
    }
  }

  // 检查会话是否正在生成
  bool isGenerating(String sessionId) {
    return _generatingStatus[sessionId] ?? false;
  }

  // 获取上次错误
  String? getLastError(String sessionId) {
    return _lastError[sessionId];
  }

  // 构建系统提示词
  String buildSystemPrompt(NovelContext context) {
    return '''
你是一位创意丰富、叙事能力极强的AI小说家助手，专注于帮助用户创作引人入胜的故事。

# 小说创作背景
${context.getFormattedContext()}

# 创作指南
1. 你的回答应该保持具有创意和沉浸感的叙事风格
2. 根据提供的小说背景信息进行创作，保持情节、风格和人物的一致性
3. 使用生动的细节、对话和情感元素让故事栩栩如生
4. 不要生硬地解释或总结情节，而是像讲故事一样自然地展开
5. 允许加入创意元素以增强故事体验，但要与已有设定保持一致
6. 回复应该作为小说内容的直接延续，不需要使用引号或前缀
7. 在用户要求时可以提供写作建议、情节方向或角色发展指导

# 回应风格
- 始终使用流畅、引人入胜的小说写作风格
- 不要使用机器人式的解释和提示语，直接给出内容
- 不要使用标题和章节编号，除非用户特别要求
- 避免使用"我"或"AI"等暴露你身份的表述，完全沉浸在创作中
- 请直接生成故事内容，不需要写"以下是小说内容"之类的开场白

现在，请根据用户的输入，继续创作或提供有关这部小说的创意建议。
''';
  }

  // 重置服务
  void reset() {
    _activeSessions.clear();
    _sessionContexts.clear();
    _generatingStatus.clear();
    _lastError.clear();
  }
} 