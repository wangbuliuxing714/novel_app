import 'dart:convert';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:novel_app/models/novel.dart';

class ChatContext {
  final String id;
  final String title;
  final String novelId;
  final String novelTitle;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic> contextData;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  ChatContext({
    required this.id,
    required this.title,
    required this.novelId,
    required this.novelTitle,
    required this.messages,
    required this.contextData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'novelId': novelId,
    'novelTitle': novelTitle,
    'messages': messages,
    'contextData': contextData,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  
  factory ChatContext.fromJson(Map<String, dynamic> json) => ChatContext(
    id: json['id'],
    title: json['title'],
    novelId: json['novelId'],
    novelTitle: json['novelTitle'],
    messages: List<Map<String, dynamic>>.from(json['messages']),
    contextData: Map<String, dynamic>.from(json['contextData']),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
  
  ChatContext copyWith({
    String? title,
    List<Map<String, dynamic>>? messages,
    Map<String, dynamic>? contextData,
    DateTime? updatedAt,
  }) {
    return ChatContext(
      id: this.id,
      title: title ?? this.title,
      novelId: this.novelId,
      novelTitle: this.novelTitle,
      messages: messages ?? this.messages,
      contextData: contextData ?? this.contextData,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class ChatContextService extends GetxService {
  static const String _boxName = 'chat_contexts';
  late Box<dynamic> _box;
  final RxList<ChatContext> chatContexts = <ChatContext>[].obs;
  
  Future<ChatContextService> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    await _loadChatContexts();
    return this;
  }
  
  Future<void> _loadChatContexts() async {
    try {
      final contexts = _box.values.map((data) {
        if (data is Map) {
          return ChatContext.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String) {
          return ChatContext.fromJson(jsonDecode(data));
        }
        throw Exception('无效的聊天上下文数据格式');
      }).toList();
      
      chatContexts.assignAll(contexts.cast<ChatContext>());
      chatContexts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      print('已加载 ${chatContexts.length} 个聊天上下文');
    } catch (e) {
      print('加载聊天上下文失败: $e');
      chatContexts.clear();
    }
  }
  
  Future<ChatContext> createChatContext({
    required String title,
    required String novelId,
    required String novelTitle,
    Map<String, dynamic>? initialContext,
  }) async {
    // 生成唯一ID
    final id = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    
    final chatContext = ChatContext(
      id: id,
      title: title,
      novelId: novelId,
      novelTitle: novelTitle,
      messages: [],
      contextData: initialContext ?? {},
    );
    
    await saveChatContext(chatContext);
    return chatContext;
  }
  
  Future<void> saveChatContext(ChatContext context) async {
    try {
      // 保存到Hive
      await _box.put(context.id, context.toJson());
      await _box.flush(); // 确保数据立即写入磁盘
      
      // 更新内存中的列表
      final index = chatContexts.indexWhere((c) => c.id == context.id);
      if (index >= 0) {
        chatContexts[index] = context;
      } else {
        chatContexts.add(context);
      }
      
      // 按更新时间排序
      chatContexts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      print('保存聊天上下文成功: ${context.title}');
    } catch (e) {
      print('保存聊天上下文失败: $e');
    }
  }
  
  Future<void> addMessage({
    required String contextId,
    required String role, // 'user', 'assistant', 'system'
    required String content,
  }) async {
    final context = chatContexts.firstWhere(
      (c) => c.id == contextId,
      orElse: () => throw Exception('找不到指定的聊天上下文'),
    );
    
    final message = {
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // 添加新消息
    final updatedMessages = List<Map<String, dynamic>>.from(context.messages)
      ..add(message);
    
    // 更新聊天上下文
    final updatedContext = context.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
    
    await saveChatContext(updatedContext);
  }
  
  Future<void> updateContextData({
    required String contextId,
    required Map<String, dynamic> newData,
  }) async {
    final context = chatContexts.firstWhere(
      (c) => c.id == contextId,
      orElse: () => throw Exception('找不到指定的聊天上下文'),
    );
    
    // 合并新旧数据
    final mergedData = Map<String, dynamic>.from(context.contextData)
      ..addAll(newData);
    
    // 更新聊天上下文
    final updatedContext = context.copyWith(
      contextData: mergedData,
      updatedAt: DateTime.now(),
    );
    
    await saveChatContext(updatedContext);
  }
  
  Future<void> deleteChatContext(String contextId) async {
    try {
      await _box.delete(contextId);
      await _box.flush();
      chatContexts.removeWhere((c) => c.id == contextId);
      print('删除聊天上下文成功');
    } catch (e) {
      print('删除聊天上下文失败: $e');
    }
  }
  
  // 从当前小说创建聊天上下文
  Future<ChatContext> createFromNovel(Novel novel) async {
    // 提取小说的关键信息作为初始上下文
    final contextData = {
      '标题': novel.title,
      '类型': novel.genre,
      '大纲': novel.outline,
      '章节数': novel.chapters.length,
      '创建时间': novel.createdAt.toIso8601String(),
    };
    
    // 如果有章节，添加章节概要
    if (novel.chapters.isNotEmpty) {
      final chaptersData = <String, String>{};
      for (var chapter in novel.chapters) {
        // 每个章节只保存标题和内容摘要（前200字）
        final summary = chapter.content.length > 200
            ? chapter.content.substring(0, 200) + '...'
            : chapter.content;
        chaptersData['第${chapter.number}章: ${chapter.title}'] = summary;
      }
      contextData['章节概要'] = chaptersData;
    }
    
    return await createChatContext(
      title: '关于《${novel.title}》的聊天',
      novelId: novel.id,
      novelTitle: novel.title,
      initialContext: contextData,
    );
  }
  
  // 根据小说ID查找所有相关的聊天上下文
  List<ChatContext> findByNovelId(String novelId) {
    return chatContexts
        .where((context) => context.novelId == novelId)
        .toList();
  }
} 