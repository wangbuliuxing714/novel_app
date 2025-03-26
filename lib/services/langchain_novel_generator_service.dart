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
    this.maxContextLength = 16000000,
    this.maxMessages = 5000,
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
      maxContextLength: json['maxContextLength'] ?? 16000000,
      maxMessages: json['maxMessages'] ?? 5000,
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
  final Map<String, ChatHistory> _sessions = {};
  final Map<String, NovelContext> _sessionContexts = {};
  final Map<String, String> _novelContent = {}; // 添加小说内容缓存
  
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
    String? novelContent, // 添加小说内容参数
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
    
    // 存储小说内容
    if (novelContent != null && novelContent.isNotEmpty) {
      _novelContent[sessionId] = novelContent;
      print('创建会话：保存小说内容，长度: ${novelContent.length}字符');
    } else {
      print('创建会话：没有小说内容');
    }
    
    // 创建会话历史
    final history = ChatHistory(sessionId: sessionId);
    
    // 添加系统消息
    history.addMessage(ChatMessage(
      role: 'system',
      content: buildSystemPrompt(context, novelContent),
    ));
    
    // 添加初始化消息
    history.addMessage(ChatMessage(
      role: 'assistant',
      content: '我已经准备好了，请告诉我您想如何开始这个故事？',
    ));
    
    // 保存会话
    _sessions[sessionId] = history;
    _sessionContexts[sessionId] = context;
    _generatingStatus[sessionId] = false;
    
    // 保存会话到缓存
    _saveSession(sessionId);
    
    return sessionId;
  }

  // 获取会话列表
  List<Map<String, dynamic>> getNovelSessions() {
    return _sessions.entries.map((entry) {
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
    return _sessions[sessionId];
  }

  // 获取特定会话的上下文
  NovelContext? getSessionContext(String sessionId) {
    return _sessionContexts[sessionId];
  }

  // 删除会话
  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
    _sessionContexts.remove(sessionId);
    _generatingStatus.remove(sessionId);
    _lastError.remove(sessionId);
    
    await saveSessions();
  }

  // 生成小说内容流
  Stream<String> generateNovelStream({
    required String sessionId,
    required String userMessage,
    double temperature = 0.7,
  }) async* {
    // 检查会话是否存在
    if (!_sessions.containsKey(sessionId)) {
      throw Exception('会话不存在');
    }
    
    // 设置生成状态
    _generatingStatus[sessionId] = true;
    
    try {
      final history = _sessions[sessionId]!;
      
      // 添加用户消息
      history.addMessage(ChatMessage(
        role: 'user',
        content: userMessage,
      ));
      
      // 打印调试信息 - 会话历史长度
      print('会话ID: $sessionId, 历史消息数量: ${history.messages.length}');
      print('传递用户消息: $userMessage');
      
      // 构建回复内容
      final StringBuffer responseBuffer = StringBuffer();
      
      // 提取历史消息并过滤掉系统消息(仅在messages参数传递)
      final historyMessages = history.messages
          .where((msg) => msg.role != 'system')
          .map((msg) => {'role': msg.role, 'content': msg.content})
          .toList();
      
      // 打印调试信息 - 传递给AI的历史消息
      print('传递给AI的历史消息数量: ${historyMessages.length}');
      
      // 获取小说内容(如果有)
      final novelContent = _novelContent[sessionId];
      final context = _sessionContexts[sessionId]!;
      
      // 更新系统提示词（确保每次生成都使用最新的小说内容）
      bool systemPromptUpdated = false;
      for (int i = 0; i < history.messages.length; i++) {
        if (history.messages[i].role == 'system') {
          final newSystemPrompt = buildSystemPrompt(context, novelContent);
          if (history.messages[i].content != newSystemPrompt) {
            history.messages[i] = ChatMessage(
              role: 'system',
              content: newSystemPrompt,
            );
            systemPromptUpdated = true;
            print('生成前更新了系统提示词');
          }
          break;
        }
      }
      
      // 如果系统提示词被更新，保存会话
      if (systemPromptUpdated) {
        await _saveSession(sessionId);
      }
      
      // 使用AI服务生成回复，传入完整历史
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: buildSystemPrompt(context, novelContent),
        userPrompt: '', // 不需要在这里传递用户消息，因为已经包含在历史中
        temperature: temperature,
        maxTokens: _apiConfig.getCurrentModel().maxTokens,
        messages: historyMessages, // 传递完整历史
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
      
      print('生成的回复长度: ${responseContent.length}字符');
      
      // 保存会话
      await _saveSession(sessionId);
      
    } catch (e) {
      _lastError[sessionId] = e.toString();
      print('生成内容失败: $e');
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
    if (!_sessions.containsKey(sessionId)) {
      throw Exception('会话不存在');
    }
    
    // 设置生成状态
    _generatingStatus[sessionId] = true;
    
    try {
      final history = _sessions[sessionId]!;
      
      // 添加用户消息
      history.addMessage(ChatMessage(
        role: 'user',
        content: userMessage,
      ));
      
      // 提取历史消息并过滤掉系统消息(仅在messages参数传递)
      final historyMessages = history.messages
          .where((msg) => msg.role != 'system')
          .map((msg) => {'role': msg.role, 'content': msg.content})
          .toList();
      
      // 获取小说内容(如果有)
      final novelContent = _novelContent[sessionId];
      final context = _sessionContexts[sessionId]!;
      
      // 生成回复，传入完整历史
      final response = await _aiService.generateText(
        systemPrompt: buildSystemPrompt(context, novelContent),
        userPrompt: '', // 不需要在这里传递用户消息，因为已经包含在历史中
        temperature: temperature,
        maxTokens: _apiConfig.getCurrentModel().maxTokens,
        messages: historyMessages, // 传递完整历史
      );
      
      // 将回复添加到历史
      history.addMessage(ChatMessage(
        role: 'assistant',
        content: response,
      ));
      
      // 保存会话
      await _saveSession(sessionId);
      
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
    if (!_sessions.containsKey(sessionId)) {
      throw Exception('会话不存在');
    }
    
    final history = _sessions[sessionId]!;
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

  // 加载所有会话
  Future<void> loadChatSessions() async {
    try {
      _sessions.clear();
      _sessionContexts.clear();
      _novelContent.clear();
      
      final sessionsJson = await _cacheService.getNovelSessions();
      if (sessionsJson != null) {
        final Map<String, dynamic> sessionsData = jsonDecode(sessionsJson);
        
        sessionsData.forEach((sessionId, sessionData) {
          final history = ChatHistory.fromJson(sessionData['history']);
          _sessions[sessionId] = history;
          
          // 恢复上下文
          if (sessionData.containsKey('context')) {
            _sessionContexts[sessionId] = NovelContext.fromJson(sessionData['context']);
          }
          
          // 恢复小说内容
          if (sessionData.containsKey('novelContent')) {
            _novelContent[sessionId] = sessionData['novelContent'];
          }
        });
      }
    } catch (e) {
      print('加载会话失败: $e');
      // 出错时不处理，使用空会话列表
    }
  }
  
  // 保存所有会话
  Future<void> saveSessions() async {
    try {
      final Map<String, dynamic> sessionsData = {};
      
      _sessions.forEach((sessionId, history) {
        final context = _sessionContexts[sessionId];
        sessionsData[sessionId] = {
          'history': history.toJson(),
          if (context != null) 'context': context.toJson(),
          if (_novelContent.containsKey(sessionId)) 'novelContent': _novelContent[sessionId],
        };
      });
      
      await _cacheService.saveNovelSessions(jsonEncode(sessionsData));
    } catch (e) {
      print('保存会话失败: $e');
      // 出错时不处理，继续使用内存中的会话
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

  // 生成聊天回复（用于岱宗AI聊天功能）
  Future<String> generateChatResponse({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
  }) async {
    try {
      print('使用LangChain生成聊天回复');
      print('系统提示词: ${systemPrompt.substring(0, min(100, systemPrompt.length))}...');
      print('用户输入: $userPrompt');
      
      // 创建临时会话
      final sessionId = 'chat_${const Uuid().v4()}';
      final history = ChatHistory(sessionId: sessionId);
      
      // 添加系统消息
      history.addMessage(ChatMessage(
        role: 'system',
        content: systemPrompt,
      ));
      
      // 添加用户消息
      history.addMessage(ChatMessage(
        role: 'user',
        content: userPrompt,
      ));
      
      // 提取历史消息，保留所有消息（包括系统消息）
      final historyMessages = history.messages
          .map((msg) => {'role': msg.role, 'content': msg.content})
          .toList();
      
      print('准备发送到AI的消息数量: ${historyMessages.length}');
      
      // 生成回复，使用完整的历史消息
      final response = await _aiService.generateText(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature,
        maxTokens: _apiConfig.getCurrentModel().maxTokens,
        messages: historyMessages, // 传递完整的历史消息，包括系统消息
      );
      
      print('AI生成的回复长度: ${response.length}字符');
      return response;
    } catch (e) {
      print('生成聊天回复失败: $e');
      throw Exception('生成聊天回复失败: $e');
    }
  }

  // 构建系统提示词
  String buildSystemPrompt(NovelContext context, [String? novelContent]) {
    final buffer = StringBuffer();
    
    buffer.writeln('''你是一位创意丰富、叙事能力极强的AI小说家助手，专注于帮助用户创作引人入胜的故事。

# 小说创作背景
${context.getFormattedContext()}''');

    // 添加小说内容作为上下文
    if (novelContent != null && novelContent.isNotEmpty) {
      buffer.writeln('\n# 小说已有内容（请确保回答与此保持一致）');
      
      // 截断过长的内容，避免超出模型上下文窗口
      final maxContentLength = 5000; // 可根据模型上下文窗口大小调整
      if (novelContent.length > maxContentLength) {
        final truncatedContent = novelContent.substring(novelContent.length - maxContentLength);
        buffer.writeln('${truncatedContent}...');
        buffer.writeln('\n(注：这里只显示了小说的最后部分内容，请确保回答与整体故事保持一致)');
        print('小说内容过长，已截断。原长度: ${novelContent.length}字符，截断后: ${truncatedContent.length}字符');
      } else {
        buffer.writeln(novelContent);
        print('添加完整小说内容到系统提示，长度: ${novelContent.length}字符');
      }
    } else {
      print('构建系统提示词：没有小说内容');
    }

    buffer.writeln('''
# 创作指南
1. 你的回答应该保持具有创意和沉浸感的叙事风格
2. 根据提供的小说背景信息和已有内容进行创作，保持情节、风格和人物的一致性
3. 使用生动的细节、对话和情感元素让故事栩栩如生
4. 不要生硬地解释或总结情节，而是像讲故事一样自然地展开
5. 允许加入创意元素以增强故事体验，但要与已有设定保持一致
6. 回复应该作为小说内容的直接延续，不需要使用引号或前缀
7. 在用户要求时可以提供写作建议、情节方向或角色发展指导
8. 请认真阅读聊天历史和小说已有内容，保持故事情节的连贯性
9. 当继续故事时，请参考小说的已有内容和之前所有消息中的情节、人物和设定

# 回应风格
- 始终使用流畅、引人入胜的小说写作风格
- 不要使用机器人式的解释和提示语，直接给出内容
- 不要使用标题和章节编号，除非用户特别要求
- 避免使用"我"或"AI"等暴露你身份的表述，完全沉浸在创作中
- 请直接生成故事内容，不需要写"以下是小说内容"之类的开场白
- 不要回顾或总结已有内容，直接延续故事

现在，请根据用户的输入，继续创作或提供有关这部小说的创意建议。''');

    final prompt = buffer.toString();
    print('生成系统提示词，长度: ${prompt.length}');
    return prompt;
  }

  // 重置服务
  void reset() {
    _sessions.clear();
    _sessionContexts.clear();
    _generatingStatus.clear();
    _lastError.clear();
  }

  // 保存特定会话
  Future<void> _saveSession(String sessionId) async {
    try {
      await saveSessions(); // 简单起见，保存所有会话
    } catch (e) {
      print('保存会话失败: $e');
    }
  }

  // 更新小说内容
  void updateNovelContent(String sessionId, String novelContent) {
    if (novelContent.isEmpty) {
      print('更新小说内容：内容为空，不更新');
      return;
    }
    
    _novelContent[sessionId] = novelContent;
    print('更新小说内容：会话ID $sessionId，内容长度: ${novelContent.length}字符');
    
    // 如果会话已存在，更新系统提示词
    if (_sessions.containsKey(sessionId) && _sessionContexts.containsKey(sessionId)) {
      final history = _sessions[sessionId]!;
      final context = _sessionContexts[sessionId]!;
      
      // 查找系统消息并更新
      for (int i = 0; i < history.messages.length; i++) {
        if (history.messages[i].role == 'system') {
          history.messages[i] = ChatMessage(
            role: 'system',
            content: buildSystemPrompt(context, novelContent),
          );
          print('已更新系统提示词');
          break;
        }
      }
    } else {
      print('更新小说内容：找不到对应的会话 $sessionId');
    }
  }
} 