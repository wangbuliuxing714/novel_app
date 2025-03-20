import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/chat_context_service.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'dart:convert';

class ChatController extends GetxController {
  final _chatContextService = Get.find<ChatContextService>();
  final _aiService = Get.find<AIService>();
  final _apiConfigController = Get.find<ApiConfigController>();
  
  final RxList<ChatContext> chatContexts = <ChatContext>[].obs;
  final Rx<ChatContext?> currentContext = Rx<ChatContext?>(null);
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxString inputText = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadChatContexts();
  }
  
  void loadChatContexts() {
    chatContexts.assignAll(_chatContextService.chatContexts);
  }
  
  Future<ChatContext> createChatContext({
    required String title,
    required String novelId,
    required String novelTitle,
    Map<String, dynamic>? initialContext,
  }) async {
    final context = await _chatContextService.createChatContext(
      title: title,
      novelId: novelId,
      novelTitle: novelTitle,
      initialContext: initialContext,
    );
    
    chatContexts.add(context);
    return context;
  }
  
  Future<ChatContext> createFromNovel(Novel novel) async {
    final context = await _chatContextService.createFromNovel(novel);
    chatContexts.add(context);
    return context;
  }
  
  void setCurrentContext(String contextId) {
    final context = chatContexts.firstWhere(
      (context) => context.id == contextId,
      orElse: () => throw Exception('找不到指定的聊天上下文'),
    );
    
    currentContext.value = context;
    messages.assignAll(context.messages);
  }
  
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || currentContext.value == null) return;
    
    final context = currentContext.value!;
    
    // 添加用户消息
    final userMessage = {
      'role': 'user',
      'content': text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    messages.add(userMessage);
    await _chatContextService.addMessage(
      contextId: context.id,
      role: 'user',
      content: text,
    );
    
    inputText.value = '';
    isLoading.value = true;
    
    try {
      // 构建系统提示词
      final systemPrompt = _buildSystemPrompt(context);
      
      // 构建历史消息
      final historyMessages = _buildHistoryMessages();
      
      // 确保所有消息都是有效的UTF-8编码
      final validMessages = historyMessages.map((msg) {
        try {
          final content = msg['content'] as String;
          final bytes = utf8.encode(content);
          final validContent = utf8.decode(bytes);
          return {
            'role': msg['role'] as String,
            'content': validContent,
          };
        } catch (e) {
          // 如果编码出现问题，尝试移除非UTF-8字符
          final cleanContent = (msg['content'] as String).replaceAll(
            RegExp(r'[^\x20-\x7E\u4E00-\u9FFF\u3000-\u303F\u00A1-\u00FF\u2000-\u206F]'), 
            ''
          );
          return {
            'role': msg['role'] as String,
            'content': cleanContent,
          };
        }
      }).toList().cast<Map<String, String>>();
      
      // 调用AI服务获取回复
      final response = await _aiService.generateChatResponse(
        systemPrompt: systemPrompt,
        messages: validMessages,
        temperature: 0.7,
        maxTokens: 1000,
      );
      
      // 添加助手回复
      final assistantMessage = {
        'role': 'assistant',
        'content': response,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      messages.add(assistantMessage);
      await _chatContextService.addMessage(
        contextId: context.id,
        role: 'assistant',
        content: response,
      );
    } catch (e) {
      print('聊天生成错误: $e');
      // 添加错误消息
      final errorMessage = {
        'role': 'system',
        'content': '发生错误: $e',
        'timestamp': DateTime.now().toIso8601String(),
        'isError': true,
      };
      
      messages.add(errorMessage);
      await _chatContextService.addMessage(
        contextId: context.id,
        role: 'system',
        content: '发生错误: $e',
      );
    } finally {
      isLoading.value = false;
    }
  }
  
  String _buildSystemPrompt(ChatContext context) {
    final contextData = context.contextData;
    final buffer = StringBuffer();
    
    buffer.writeln('你是一个基于上下文和历史消息提供帮助的AI助手。');
    buffer.writeln('以下是关于《${context.novelTitle}》的背景信息，请基于这些信息回答用户的问题。');
    buffer.writeln();
    
    // 添加所有上下文数据
    contextData.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('$key:');
        (value as Map).forEach((subKey, subValue) {
          buffer.writeln('  $subKey: $subValue');
        });
      } else {
        buffer.writeln('$key: $value');
      }
    });
    
    return buffer.toString();
  }
  
  List<Map<String, String>> _buildHistoryMessages() {
    // 最多取最近10条消息
    final recentMessages = messages.length > 10 
        ? messages.sublist(messages.length - 10) 
        : messages;
    
    return recentMessages.map((msg) => {
      'role': msg['role'] as String,
      'content': msg['content'] as String,
    }).toList();
  }
  
  Future<void> clearMessages() async {
    if (currentContext.value == null) return;
    
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有聊天记录吗？这个操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // 清空消息，但保留上下文数据
      final updatedContext = currentContext.value!.copyWith(
        messages: [],
        updatedAt: DateTime.now(),
      );
      
      await _chatContextService.saveChatContext(updatedContext);
      currentContext.value = updatedContext;
      messages.clear();
    }
  }
  
  Future<void> deleteContext() async {
    if (currentContext.value == null) return;
    
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个聊天吗？所有聊天记录将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final contextId = currentContext.value!.id;
      await _chatContextService.deleteChatContext(contextId);
      
      // 更新列表和当前上下文
      chatContexts.removeWhere((c) => c.id == contextId);
      currentContext.value = null;
      messages.clear();
      
      Get.back(); // 返回上一页
    }
  }
  
  Future<void> updateContextTitle(String newTitle) async {
    if (currentContext.value == null || newTitle.trim().isEmpty) return;
    
    final updatedContext = currentContext.value!.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    
    await _chatContextService.saveChatContext(updatedContext);
    currentContext.value = updatedContext;
    
    // 更新列表中的数据
    final index = chatContexts.indexWhere((c) => c.id == updatedContext.id);
    if (index >= 0) {
      chatContexts[index] = updatedContext;
    }
  }
} 