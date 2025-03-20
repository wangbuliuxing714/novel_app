import 'package:langchain/langchain.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/models/conversation_message.dart';
import 'package:novel_app/utils/app_constants.dart';

class LangChainService extends GetxService {
  final ApiConfigController _apiConfig;
  final Map<String, ConversationChain> _conversations = {};
  final Map<String, List<ConversationMessage>> _conversationHistory = {};

  LangChainService(this._apiConfig);

  // 初始化会话
  Future<void> initializeConversation(String sessionId, {String? systemPrompt}) async {
    final llm = ChatOpenAI(
      apiKey: _apiConfig.getCurrentModel().apiKey,
      baseUrl: _apiConfig.getCurrentModel().apiUrl,
      model: _apiConfig.getCurrentModel().model,
      temperature: _apiConfig.getCurrentModel().temperature,
      maxTokens: _apiConfig.getCurrentModel().maxTokens,
    );

    final memory = ConversationBufferMemory(
      returnMessages: true,
      memoryKey: "chat_history",
      inputKey: "input",
      outputKey: "output",
      humanPrefix: "Human",
      aiPrefix: "Assistant",
    );

    final prompt = PromptTemplate.fromTemplate(
      systemPrompt ?? "You are a helpful AI assistant. {chat_history}\nHuman: {input}\nAssistant: ",
    );

    final chain = ConversationChain(
      llm: llm,
      memory: memory,
      prompt: prompt,
    );

    _conversations[sessionId] = chain;
    _conversationHistory[sessionId] = [];
  }

  // 添加背景信息到会话
  Future<void> addBackgroundInfo(String sessionId, Map<String, dynamic> backgroundInfo) async {
    if (!_conversations.containsKey(sessionId)) {
      throw Exception('会话未初始化');
    }

    final conversation = _conversations[sessionId]!;
    final formattedBackground = _formatBackgroundInfo(backgroundInfo);
    
    // 将背景信息作为系统消息添加到历史记录
    _conversationHistory[sessionId]!.add(
      ConversationMessage(
        role: 'system',
        content: formattedBackground,
      ),
    );

    // 更新会话记忆
    await conversation.memory.saveContext(
      {'input': 'Background information'},
      {'output': formattedBackground},
    );
  }

  // 生成内容
  Stream<String> generateContent(String sessionId, String prompt) async* {
    if (!_conversations.containsKey(sessionId)) {
      throw Exception('会话未初始化');
    }

    final conversation = _conversations[sessionId]!;
    
    // 添加用户输入到历史记录
    _conversationHistory[sessionId]!.add(
      ConversationMessage(
        role: 'user',
        content: prompt,
      ),
    );

    String response = '';
    await for (final chunk in conversation.stream({
      'input': prompt,
    })) {
      response += chunk;
      yield chunk;
    }

    // 添加AI响应到历史记录
    _conversationHistory[sessionId]!.add(
      ConversationMessage(
        role: 'assistant',
        content: response,
      ),
    );

    // 如果历史记录超过最大限制，移除最早的消息
    while (_conversationHistory[sessionId]!.length > AppConstants.maxConversationHistory) {
      _conversationHistory[sessionId]!.removeAt(0);
    }
  }

  // 获取会话历史
  List<ConversationMessage> getConversationHistory(String sessionId) {
    return _conversationHistory[sessionId] ?? [];
  }

  // 清除会话
  void clearConversation(String sessionId) {
    _conversations.remove(sessionId);
    _conversationHistory.remove(sessionId);
  }

  // 格式化背景信息
  String _formatBackgroundInfo(Map<String, dynamic> backgroundInfo) {
    final buffer = StringBuffer();
    buffer.writeln('背景信息：');
    
    backgroundInfo.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        buffer.writeln('$key: $value');
      }
    });
    
    return buffer.toString();
  }
} 