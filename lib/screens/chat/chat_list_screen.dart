import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/chat_controller.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/services/chat_context_service.dart';
import 'package:novel_app/screens/chat/chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final novelController = Get.find<NovelController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('关于聊天功能'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '聊天功能允许您基于已创建的小说上下文进行对话。\n\n'
                      '每个聊天都会记住关于小说的重要信息，您可以询问情节、角色、创作思路等问题。\n\n'
                      '系统会自动将小说的关键信息作为上下文，帮助AI更好地理解您的问题。\n\n'
                      '您还可以查看上下文信息，了解AI在回答问题时使用的背景知识。'
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('了解了'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Obx(() {
        final contexts = chatController.chatContexts;
        
        if (contexts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  '没有聊天记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '创建一个新的聊天开始对话',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _showNovelSelectionDialog(context),
                  child: const Text('创建新聊天'),
                ),
              ],
            ),
          );
        }
        
        // 对聊天上下文按更新时间排序
        final sortedContexts = contexts.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        
        return ListView.builder(
          itemCount: sortedContexts.length,
          itemBuilder: (context, index) {
            final context = sortedContexts[index];
            final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
            final formattedDate = dateFormat.format(context.updatedAt);
            
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.chat),
              ),
              title: Text(context.title),
              subtitle: Text(
                '小说：${context.novelTitle} · $formattedDate',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                chatController.setCurrentContext(context.id);
                Get.to(() => const ChatScreen());
              },
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNovelSelectionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
  
  void _showNovelSelectionDialog(BuildContext context) {
    final novelController = Get.find<NovelController>();
    final chatController = Get.find<ChatController>();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择小说'),
          content: SizedBox(
            width: double.maxFinite,
            child: Obx(() {
              final novels = novelController.novels;
              
              if (novels.isEmpty) {
                return const Center(
                  child: Text(
                    '没有已创建的小说',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                itemCount: novels.length,
                itemBuilder: (context, index) {
                  final novel = novels[index];
                  return ListTile(
                    title: Text(novel.title),
                    subtitle: Text(
                      '类型：${novel.genre} · ${novel.chapters.length}章',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final chatContext = await chatController.createFromNovel(novel);
                      chatController.setCurrentContext(chatContext.id);
                      Get.to(() => const ChatScreen());
                    },
                  );
                },
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
} 