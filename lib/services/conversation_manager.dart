import 'dart:math';

// 对话会话管理类
class ConversationManager {
  // 存储对话历史的映射表，键为对话ID，值为对话历史
  static final Map<String, List<Map<String, dynamic>>> _conversations = {};
  
  // 生成一个新的对话ID
  static String createConversation() {
    final id = 'conv_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    _conversations[id] = [];
    return id;
  }
  
  // 向对话中添加一条消息
  static void addMessage(String conversationId, String role, String content) {
    if (!_conversations.containsKey(conversationId)) {
      _conversations[conversationId] = [];
    }
    
    // 防止空消息添加
    if (content.trim().isEmpty) {
      print('尝试添加空消息被阻止');
      return;
    }
    
    // 添加消息时间戳
    final message = {
      'role': role,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    };
    
    // 检查是否是重复消息
    final messages = _conversations[conversationId]!;
    
    // 如果消息列表不为空，检查最后一条消息
    if (messages.isNotEmpty) {
      final lastMessage = messages.last;
      
      // 检查是否完全相同的消息（角色和内容都相同）
      if (lastMessage['role'] == role && lastMessage['content'] == content) {
        print('阻止添加完全相同的消息');
        return;
      }
      
      // 如果是用户消息且内容较长，检查前面部分是否相同（可能是重复提交）
      if (role == 'user' && content.length > 100 && lastMessage['role'] == 'user') {
        final lastContent = lastMessage['content'] as String;
        if (lastContent.length > 100) {
          if (content.substring(0, 100) == lastContent.substring(0, 100)) {
            print('阻止添加相似用户消息');
            return;
          }
        }
      }
    }
    
    _conversations[conversationId]?.add(message);
  }
  
  // 获取对话历史
  static List<Map<String, dynamic>> getMessages(String conversationId) {
    return _conversations[conversationId] ?? [];
  }
  
  // 清除对话历史
  static void clearConversation(String conversationId) {
    _conversations.remove(conversationId);
  }
  
  // 获取特定长度的对话历史（最近的n条）
  static List<Map<String, dynamic>> getRecentMessages(String conversationId, int count) {
    final messages = _conversations[conversationId] ?? [];
    if (messages.length <= count) {
      return messages;
    }
    return messages.sublist(messages.length - count);
  }
  
  // 获取所有会话ID
  static List<String> getAllConversationIds() {
    return _conversations.keys.toList();
  }
  
  // 获取会话统计信息
  static Map<String, int> getConversationStats(String conversationId) {
    if (!_conversations.containsKey(conversationId)) {
      return {
        'system': 0,
        'user': 0,
        'assistant': 0,
        'total': 0,
      };
    }
    
    final messages = _conversations[conversationId]!;
    int systemCount = 0;
    int userCount = 0;
    int assistantCount = 0;
    
    for (var message in messages) {
      if (message['role'] == 'system') {
        systemCount++;
      } else if (message['role'] == 'user') {
        userCount++;
      } else if (message['role'] == 'assistant') {
        assistantCount++;
      }
    }
    
    return {
      'system': systemCount,
      'user': userCount,
      'assistant': assistantCount,
      'total': systemCount + userCount + assistantCount,
    };
  }
  
  // 清除所有会话
  static void clearAllConversations() {
    _conversations.clear();
    print('已清除全部会话历史');
  }
  
  // 获取会话总数
  static int getConversationCount() {
    return _conversations.length;
  }
  
  // 获取消息总数
  static int getTotalMessageCount() {
    int count = 0;
    for (final messages in _conversations.values) {
      count += messages.length;
    }
    return count;
  }
  
  // 导出所有会话记录为JSON格式
  static Map<String, dynamic> exportAllConversations() {
    Map<String, dynamic> result = {};
    
    for (var entry in _conversations.entries) {
      String conversationId = entry.key;
      List<Map<String, dynamic>> messages = entry.value;
      
      result[conversationId] = {
        'messages': messages,
        'created_at': DateTime.now().toIso8601String(),
      };
    }
    
    return result;
  }
} 