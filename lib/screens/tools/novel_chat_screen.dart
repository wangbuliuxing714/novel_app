import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/services/langchain_novel_generator_service.dart';
import 'package:novel_app/widgets/common/loading_overlay.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class NovelChatController extends GetxController {
  final LangchainNovelGeneratorService novelGenerator = Get.find<LangchainNovelGeneratorService>();
  final NovelController novelController = Get.find<NovelController>();
  final ApiConfigController apiConfigController = Get.find<ApiConfigController>();
  
  RxList<ChatMessage> messages = <ChatMessage>[].obs;
  RxBool isGenerating = false.obs;
  RxString currentSessionId = ''.obs;
  Rx<NovelContext?> currentContext = Rx<NovelContext?>(null);
  RxBool hasNovelContent = false.obs;
  
  final textController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    loadSessions();
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // 加载会话
  Future<void> loadSessions() async {
    await novelGenerator.loadChatSessions();
    
    // 如果没有活动会话但有小说，创建新会话
    if (novelGenerator.getNovelSessions().isEmpty && novelController.novels.isNotEmpty) {
      await _createSessionFromCurrentNovel();
    }
  }

  // 创建从当前小说创建会话
  Future<void> _createSessionFromCurrentNovel() async {
    final novel = novelController.novels.isNotEmpty 
        ? novelController.novels.first 
        : null;
        
    if (novel == null) return;
    
    final characterCards = <String, dynamic>{};
    final worldBuilding = <String, dynamic>{};
    
    // 创建会话
    String outline = novel.outline;
    
    // 提取小说完整内容
    String novelContent = '';
    if (novel.chapters.isNotEmpty) {
      // 按章节号排序
      final sortedChapters = List<Chapter>.from(novel.chapters)
        ..sort((a, b) => a.number.compareTo(b.number));
      
      // 合并所有章节内容
      novelContent = sortedChapters.map((chapter) => 
        "第${chapter.number}章：${chapter.title}\n\n${chapter.content}"
      ).join('\n\n');
      
      print('提取小说内容：${novel.title}，共${novel.chapters.length}章');
      hasNovelContent.value = true;
    } else if (novel.content.isNotEmpty) {
      // 使用整体内容
      novelContent = novel.content;
      print('提取小说内容：${novel.title}，使用整体内容');
      hasNovelContent.value = true;
    } else {
      hasNovelContent.value = false;
    }
    
    // 检查是否已存在会话ID，若存在则不创建新会话
    if (currentSessionId.value.isEmpty) {
      final sessionId = novelGenerator.createNovelSession(
        title: novel.title,
        genre: novel.genre,
        plotOutline: outline,
        characters: characterCards,
        worldBuilding: worldBuilding,
        style: novel.style ?? '',
        tone: novel.style ?? '',
        novelContent: novelContent, // 传递小说内容
      );
      
      currentSessionId.value = sessionId;
    } else {
      // 更新现有会话的小说内容
      novelGenerator.updateNovelContent(currentSessionId.value, novelContent);
    }
    
    _updateMessages();
    
    // 更新上下文
    currentContext.value = novelGenerator.getSessionContext(currentSessionId.value);
  }

  // 更新消息列表
  void _updateMessages() {
    if (currentSessionId.value.isNotEmpty) {
      final history = novelGenerator.getSession(currentSessionId.value);
      if (history != null) {
        messages.value = List.from(history.messages);
      }
    }
  }

  // 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || isGenerating.value) return;
    
    if (currentSessionId.value.isEmpty) {
      await _createSessionFromCurrentNovel();
    }
    
    // 清空输入框
    textController.clear();
    
    try {
      isGenerating.value = true;
      
      // 添加用户消息到UI（实际添加到历史的操作在服务中进行）
      final userMessage = ChatMessage(
        role: 'user',
        content: content,
      );
      messages.add(userMessage);
      
      // 滚动到底部
      _scrollToBottom();
      
      // 添加临时的AI消息（显示正在生成）
      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: '...',
      );
      messages.add(assistantMessage);
      
      // 开始生成
      String generatedText = '';
      final sessionId = currentSessionId.value;
      
      final stream = novelGenerator.generateNovelStream(
        sessionId: sessionId,
        userMessage: content,
        temperature: 0.7,
      );
      
      // 处理流式响应
      await for (final chunk in stream) {
        generatedText += chunk;
        
        // 更新消息内容
        final lastIndex = messages.length - 1;
        messages[lastIndex] = ChatMessage(
          role: 'assistant',
          content: generatedText,
        );
        
        // 每次更新后滚动到底部
        _scrollToBottom();
      }
      
      // 更新最终消息
      final lastIndex = messages.length - 1;
      messages[lastIndex] = ChatMessage(
        role: 'assistant',
        content: generatedText,
      );
      
      _scrollToBottom();
    } catch (e) {
      Get.snackbar(
        '生成失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isGenerating.value = false;
    }
  }

  // 滚动到底部
  void _scrollToBottom() {
    if (scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }
  
  // 清空聊天记录
  void clearChat() {
    if (currentSessionId.value.isNotEmpty) {
      final history = novelGenerator.getSession(currentSessionId.value);
      if (history != null) {
        history.clear();
        
        // 添加初始系统消息
        if (currentContext.value != null) {
          history.addMessage(ChatMessage(
            role: 'system',
            content: _buildSystemPrompt(currentContext.value!),
          ));
        }
        
        // 添加欢迎消息
        history.addMessage(ChatMessage(
          role: 'assistant',
          content: '我已经准备好了，请告诉我您想如何开始这个故事？',
        ));
        
        _updateMessages();
      }
    }
  }
  
  // 创建系统提示词
  String _buildSystemPrompt(NovelContext context) {
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
  
  // 导出聊天记录为小说
  Future<void> exportChatAsNovel() async {
    if (currentSessionId.value.isEmpty) return;
    
    try {
      final novel = await novelGenerator.exportNovel(currentSessionId.value);
      novelController.saveNovel(novel);
      
      // 导出后更新会话内容
      final novelContent = novel.content;
      novelGenerator.updateNovelContent(currentSessionId.value, novelContent);
      
      Get.snackbar(
        '导出成功',
        '已将对话导出为小说',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '导出失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  // 获取特定角色的提示信息
  String getCharacterPrompt(String characterName) {
    if (currentContext.value == null) return '';
    final characters = currentContext.value!.characters;
    if (!characters.containsKey(characterName)) return '';
    
    final character = characters[characterName];
    return '请以${characterName}的身份回答，考虑到TA的性格特点和背景故事。';
  }
  
  // 获取情节发展建议
  String getPlotSuggestion() {
    return '请给出一些情节发展的建议，包括可能的转折点和冲突。';
  }

  // 刷新小说内容上下文
  Future<void> refreshNovelContent() async {
    if (currentSessionId.value.isEmpty) return;
    
    final novel = novelController.novels.isNotEmpty 
        ? novelController.novels.first 
        : null;
        
    if (novel == null) {
      Get.snackbar(
        '刷新失败',
        '没有找到小说数据',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    
    // 提取小说完整内容
    String novelContent = '';
    if (novel.chapters.isNotEmpty) {
      // 按章节号排序
      final sortedChapters = List<Chapter>.from(novel.chapters)
        ..sort((a, b) => a.number.compareTo(b.number));
      
      // 合并所有章节内容
      novelContent = sortedChapters.map((chapter) => 
        "第${chapter.number}章：${chapter.title}\n\n${chapter.content}"
      ).join('\n\n');
      
      print('刷新小说内容：${novel.title}，共${novel.chapters.length}章');
      hasNovelContent.value = true;
    } else if (novel.content.isNotEmpty) {
      // 使用整体内容
      novelContent = novel.content;
      print('刷新小说内容：${novel.title}，使用整体内容');
      hasNovelContent.value = true;
    } else {
      hasNovelContent.value = false;
    }
    
    // 更新会话的小说内容
    novelGenerator.updateNovelContent(currentSessionId.value, novelContent);
    
    Get.snackbar(
      '刷新成功',
      '已更新小说内容上下文',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class NovelChatScreen extends StatelessWidget {
  const NovelChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NovelChatController());
    
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          return Row(
            children: [
              Text('与小说对话'),
              SizedBox(width: 10),
              if (controller.hasNovelContent.value)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '已加载小说内容',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
            ],
          );
        }),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: '刷新小说内容',
            onPressed: () => controller.refreshNovelContent(),
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep),
            tooltip: '清空聊天',
            onPressed: () => _showClearChatDialog(context, controller),
          ),
          IconButton(
            icon: Icon(Icons.save_alt),
            tooltip: '导出为小说',
            onPressed: () => controller.exportChatAsNovel(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 聊天记录
          Expanded(
            child: Obx(() => LoadingOverlay(
              isLoading: controller.isGenerating.value,
              loadingText: '正在思考...',
              child: _buildChatList(controller),
            )),
          ),
          
          // 快捷按钮
          _buildQuickButtons(controller),
          
          // 输入框
          _buildInputField(context, controller),
        ],
      ),
    );
  }
  
  Widget _buildChatList(NovelChatController controller) {
    return ListView.builder(
      controller: controller.scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: controller.messages.length,
      itemBuilder: (context, index) {
        final message = controller.messages[index];
        
        // 忽略系统消息
        if (message.role == 'system') return SizedBox.shrink();
        
        return _buildChatBubble(context, message, controller);
      },
    );
  }
  
  Widget _buildChatBubble(BuildContext context, ChatMessage message, NovelChatController controller) {
    final isUser = message.role == 'user';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser 
              ? Theme.of(context).primaryColor.withOpacity(0.9) 
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? '您' : '小说助手',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isUser 
                    ? Colors.white70 
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            SizedBox(height: 4),
            SelectableText(
              message.content,
              style: TextStyle(
                color: isUser 
                    ? Colors.white 
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickButtons(NovelChatController controller) {
    return Obx(() {
      if (controller.currentContext.value == null) return SizedBox.shrink();
      
      // 获取角色列表
      final characters = controller.currentContext.value!.characters.keys.toList();
      
      return Container(
        height: 40,
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          children: [
            // 情节建议按钮
            _buildPromptButton(
              '情节建议',
              Icons.lightbulb_outline,
              () => controller.textController.text = controller.getPlotSuggestion(),
            ),
            
            // 角色对话按钮
            ...characters.map((name) => _buildPromptButton(
              name,
              Icons.person_outline,
              () => controller.textController.text = controller.getCharacterPrompt(name),
            )),
          ],
        ),
      );
    });
  }
  
  Widget _buildPromptButton(String label, IconData icon, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInputField(BuildContext context, NovelChatController controller) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.textController,
              decoration: InputDecoration(
                hintText: '与小说对话...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  controller.sendMessage(value);
                }
              },
            ),
          ),
          SizedBox(width: 8),
          Obx(() => IconButton(
            icon: Icon(
              Icons.send,
              color: controller.isGenerating.value
                  ? Colors.grey
                  : Theme.of(context).primaryColor,
            ),
            onPressed: controller.isGenerating.value
                ? null
                : () => controller.sendMessage(controller.textController.text),
          )),
        ],
      ),
    );
  }
  
  void _showClearChatDialog(BuildContext context, NovelChatController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空聊天'),
        content: Text('确定要清空所有聊天记录吗？这个操作不能撤销。'),
        actions: [
          TextButton(
            child: Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('确定'),
            onPressed: () {
              controller.clearChat();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
} 