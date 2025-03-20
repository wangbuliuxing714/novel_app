import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/chat_controller.dart';
import 'package:novel_app/services/chat_context_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final scrollController = ScrollController();
    final textController = TextEditingController();
    
    // 监听消息列表变化，自动滚动到底部
    ever(chatController.messages, (_) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
      );
    });
    
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final context = chatController.currentContext.value;
          return Text(context?.title ?? '聊天');
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showContextInfoDialog(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  _showRenameDialog(context);
                  break;
                case 'clear':
                  await chatController.clearMessages();
                  break;
                case 'delete':
                  await chatController.deleteContext();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Text('重命名'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('清除消息'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除聊天'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: Obx(() {
              final messages = chatController.messages;
              
              if (messages.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 56,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '开始聊天吧',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageBubble(message);
                },
              );
            }),
          ),
          
          // 输入区域
          Obx(() {
            final isLoading = chatController.isLoading.value;
            
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: isLoading
                          ? null
                          : (text) {
                              if (text.trim().isNotEmpty) {
                                chatController.sendMessage(text);
                                textController.clear();
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () {
                              final text = textController.text;
                              if (text.trim().isNotEmpty) {
                                chatController.sendMessage(text);
                                textController.clear();
                              }
                            },
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    final isError = message['isError'] == true;
    
    String content = message['content'] ?? '';
    
    // 检查内容是否包含乱码，如果包含则尝试修复或显示替代文本
    if (!isUser && !isError && _containsInvalidChars(content)) {
      try {
        // 尝试过滤掉乱码字符
        content = _sanitizeText(content);
        if (content.trim().isEmpty) {
          content = '[无法显示的内容]';
        }
      } catch (e) {
        content = '[内容显示错误]';
      }
    }
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError 
              ? Colors.red.shade100
              : (isUser 
                  ? Colors.blue.shade100 
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(Get.context!).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? '您' : (isError ? '系统' : '助手'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isError 
                    ? Colors.red 
                    : (isUser ? Colors.blue.shade700 : Colors.black87),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              content,
              style: TextStyle(
                color: isError ? Colors.red.shade900 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTimestamp(message['timestamp']),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 检测文本是否包含乱码或无效字符
  bool _containsInvalidChars(String text) {
    // 检查常见的乱码字符和替代字符
    return text.contains('') || 
           text.contains('\ufffd') || 
           RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(text);
  }
  
  // 清理文本中的乱码
  String _sanitizeText(String text) {
    // 仅保留基本ASCII、中文文字和标点符号
    return text.replaceAll(
      RegExp(r'[^\x20-\x7E\u4E00-\u9FFF\u3000-\u303F\u00A1-\u00FF\u2000-\u206F]'), 
      ''
    );
  }
  
  void _showContextInfoDialog(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final currentContext = chatController.currentContext.value;
    
    if (currentContext == null) {
      Get.snackbar('错误', '没有找到聊天上下文');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('上下文信息'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '小说: ${currentContext.novelTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '上下文数据:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...currentContext.contextData.entries.map((entry) {
                    return _buildContextEntry(entry.key, entry.value);
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildContextEntry(String key, dynamic value) {
    if (value is Map) {
      return ExpansionTile(
        title: Text(key),
        children: value.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _buildContextEntry(entry.key.toString(), entry.value),
          );
        }).toList(),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 14),
            ),
            const Divider(),
          ],
        ),
      );
    }
  }
  
  void _showRenameDialog(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final currentContext = chatController.currentContext.value;
    
    if (currentContext == null) {
      Get.snackbar('错误', '没有找到聊天上下文');
      return;
    }
    
    final textController = TextEditingController(text: currentContext.title);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名聊天'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: '聊天名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final newTitle = textController.text.trim();
                if (newTitle.isNotEmpty) {
                  chatController.updateContextTitle(newTitle);
                  Navigator.pop(context);
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
  
  String _formatTimestamp(String timestamp) {
    final date = DateTime.parse(timestamp);
    return DateFormat('HH:mm').format(date);
  }
} 