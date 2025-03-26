import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/services/langchain_novel_generator_service.dart';

class DaizongAIController extends GetxController {
  final AIService _aiService = Get.find<AIService>();
  final NovelController _novelController = Get.find<NovelController>();
  final LangchainNovelGeneratorService _langchainService = Get.find<LangchainNovelGeneratorService>();
  
  final RxBool isGenerating = false.obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final TextEditingController textController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  
  // 当前聊天模式: 'normal' 或 'novel'
  final RxString chatMode = 'normal'.obs;
  
  // 当前选择的小说（用于小说对话模式）
  final Rx<Novel?> selectedNovel = Rx<Novel?>(null);
  
  @override
  void onInit() {
    super.onInit();
    // 添加欢迎消息
    messages.add(ChatMessage(
      content: '您好，我是岱宗AI，可以为您提供创作助手服务。您可以与我聊天，或者选择一部小说与我进行针对性讨论。',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }
  
  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }
  
  // 切换聊天模式
  void switchChatMode(String mode) {
    if (mode != chatMode.value) {
      chatMode.value = mode;
      if (mode == 'novel' && selectedNovel.value == null && _novelController.novels.isNotEmpty) {
        selectedNovel.value = _novelController.novels.first;
      }
      
      // 添加模式切换提示
      if (mode == 'normal') {
        messages.add(ChatMessage(
          content: '已切换到普通聊天模式。有什么可以帮您的？',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      } else {
        final novel = selectedNovel.value;
        if (novel != null) {
          messages.add(ChatMessage(
            content: '已切换到小说对话模式。我们正在讨论《${novel.title}》，您可以询问关于情节、人物或创作建议的问题。',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        } else {
          messages.add(ChatMessage(
            content: '请先选择一部小说再进行小说对话。',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      }
      
      _scrollToBottom();
    }
  }
  
  // 选择小说
  void selectNovel(Novel novel) {
    selectedNovel.value = novel;
    messages.add(ChatMessage(
      content: '已选择《${novel.title}》。您可以询问关于这部小说的任何问题。',
      isUser: false,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();
  }
  
  // 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || isGenerating.value) return;
    
    // 清空输入框
    textController.clear();
    
    // 添加用户消息
    final userMessage = ChatMessage(
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);
    
    // 滚动到底部
    _scrollToBottom();
    
    // 添加临时AI消息
    final tempAiMessage = ChatMessage(
      content: '...',
      isUser: false,
      timestamp: DateTime.now(),
    );
    messages.add(tempAiMessage);
    
    try {
      isGenerating.value = true;
      
      String response = '';
      
      if (chatMode.value == 'novel' && selectedNovel.value != null) {
        final novel = selectedNovel.value!;
        
        // 获取小说的所有章节内容作为上下文
        final chapters = novel.chapters;
        String chaptersContent = '';
        
        if (chapters.isNotEmpty) {
          // 构建章节内容字符串，限制总长度以避免超出token限制
          for (var chapter in chapters) {
            if (chaptersContent.length < 1500000) {  // 限制上下文长度
              chaptersContent += '${chapter.title}:\n${chapter.content}\n\n';
            } else {
              break;
            }
          }
          
          print('小说《${novel.title}》章节数: ${chapters.length}, 上下文长度: ${chaptersContent.length}');
        }
        
        // 准备系统提示
        String systemPrompt = '''
你是一个专业的小说顾问，能够深入分析和讨论小说内容。

小说标题：${novel.title}
小说类型：${novel.genre}
小说大纲：${novel.outline}

以下是小说的章节内容：
$chaptersContent

请基于这部小说的内容提供有深度的回答。当被问及情节、人物或创作建议时，提供具体且有建设性的意见，帮助用户更好地理解和完善他们的小说。
''';
        
        // 使用LangChain处理对话
        response = await _langchainService.generateChatResponse(
          systemPrompt: systemPrompt,
          userPrompt: content,
          temperature: 0.7,
        );
      } else {
        // 标准聊天模式
        String systemPrompt = '''
你是岱宗AI，一个友好、专业的助手，擅长聊天和提供帮助。你的回答应该简洁、清晰，且富有帮助性。在交流中保持友好的语气，并尽量提供有价值的信息。
''';
        
        // 使用LangChain处理对话
        response = await _langchainService.generateChatResponse(
          systemPrompt: systemPrompt,
          userPrompt: content,
          temperature: 0.7,
        );
      }
      
      // 更新AI消息
      final index = messages.length - 1;
      messages[index] = ChatMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      
      _scrollToBottom();
    } catch (e) {
      // 错误处理
      final index = messages.length - 1;
      messages[index] = ChatMessage(
        content: '抱歉，生成回复时出现错误: $e',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
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
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  
  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class DaizongAIScreen extends StatelessWidget {
  const DaizongAIScreen({Key? key}) : super(key: key);

  // 定义主题色
  static const Color earthYellow = Color(0xFFD4B483);
  static const Color forestGreen = Color(0xFF3A6B35);
  static const Color lightGreen = Color(0xFF93B884);
  static const Color lightYellow = Color(0xFFF2E3BC);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DaizongAIController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('岱宗AI'),
        backgroundColor: forestGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 模式选择器
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : lightYellow,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Obx(() => Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'normal',
                        label: Text('普通聊天'),
                        icon: Icon(Icons.chat_bubble_outline),
                      ),
                      ButtonSegment<String>(
                        value: 'novel',
                        label: Text('小说对话'),
                        icon: Icon(Icons.book_outlined),
                      ),
                    ],
                    selected: {controller.chatMode.value},
                    onSelectionChanged: (Set<String> selection) {
                      controller.switchChatMode(selection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (states) {
                          if (states.contains(MaterialState.selected)) {
                            return forestGreen;
                          }
                          return isDark ? Colors.grey.shade700 : Colors.white;
                        },
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (states) {
                          if (states.contains(MaterialState.selected)) {
                            return Colors.white;
                          }
                          return isDark ? Colors.white : Colors.black87;
                        },
                      ),
                    ),
                  ),
                )),
                
                // 小说选择器（仅在小说对话模式下显示）
                Obx(() => controller.chatMode.value == 'novel'
                    ? Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: _buildNovelSelector(controller),
                      )
                    : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          // 消息列表
          Expanded(
            child: Container(
              color: isDark ? Colors.grey.shade900 : lightYellow.withOpacity(0.2),
              child: Obx(() => ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: controller.messages.length,
                itemBuilder: (context, index) {
                  final message = controller.messages[index];
                  return _buildMessageBubble(context, message, isDark);
                },
              )),
            ),
          ),
          
          // 输入框区域
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.textController,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark 
                          ? Colors.grey.shade700 
                          : lightYellow.withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        controller.sendMessage(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => Material(
                  color: forestGreen,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: controller.isGenerating.value
                        ? null
                        : () => controller.sendMessage(controller.textController.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: controller.isGenerating.value
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                            ),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovelSelector(DaizongAIController controller) {
    final novels = Get.find<NovelController>().novels;
    
    return DropdownButton<Novel>(
      value: controller.selectedNovel.value,
      hint: const Text('选择小说'),
      underline: Container(height: 0),
      icon: const Icon(Icons.arrow_drop_down),
      iconEnabledColor: forestGreen,
      onChanged: (Novel? novel) {
        if (novel != null) {
          controller.selectNovel(novel);
        }
      },
      items: novels.map<DropdownMenuItem<Novel>>((Novel novel) {
        return DropdownMenuItem<Novel>(
          value: novel,
          child: SizedBox(
            width: 100,
            child: Text(
              novel.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message, bool isDark) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser
              ? forestGreen
              : message.isError
                  ? Colors.red.shade100
                  : (isDark ? Colors.grey.shade700 : earthYellow.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.isUser ? '我' : '岱宗AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: message.isUser
                    ? Colors.white70
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              message.content,
              style: TextStyle(
                color: message.isUser
                    ? Colors.white
                    : message.isError
                        ? Colors.red.shade900
                        : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 