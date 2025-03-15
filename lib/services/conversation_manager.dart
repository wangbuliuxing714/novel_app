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
    
    _conversations[conversationId]?.add({
      'role': role,
      'content': content
    });
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
} 