import 'package:get/get.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';

class BackgroundGeneratorService extends GetxService {
  final AIService _aiService;
  final PromptPackageController _promptPackageController;
  
  BackgroundGeneratorService(
    this._aiService,
    this._promptPackageController,
  );
  
  Future<String> generateBackground({
    required String title,
    required String genre,
    String? initialIdea,
    bool isDetailed = false,
  }) async {
    // 获取背景提示词包
    final backgroundPrompt = _promptPackageController.getDefaultPromptPackage('background');
    final promptContent = backgroundPrompt?.content ?? '';
    
    // 构建生成背景的提示词
    final prompt = '''
你是一位专业的小说世界观设计师，请为以下小说创建一个丰富、一致且有深度的故事背景：

【小说信息】
- 标题：$title
- 类型：$genre
${initialIdea != null && initialIdea.isNotEmpty ? '- 初始构想：$initialIdea' : ''}

$promptContent

请创建一个${isDetailed ? '详细的' : '简洁的'}故事背景，包括以下方面：
1. 世界观概述：整体世界设定的简要描述
2. 物理环境：地理环境、气候特点、建筑风格等
3. 社会结构：政治体系、经济系统、社会阶层等
4. 文化元素：历史背景、宗教信仰、风俗习惯等
5. 特殊规则：该世界特有的规则、魔法系统或科技水平等
6. 主要冲突：世界中存在的主要矛盾和冲突来源

${isDetailed ? '请提供详细的描述，包括具体的地名、组织名称、历史事件等细节，使世界观更加丰满。' : '请提供简洁的描述，突出最重要的元素，便于读者快速理解。'}

确保创建的世界观与小说类型相符，并为故事发展提供丰富的可能性。
''';

    try {
      // 调用AI服务生成背景
      final response = await _aiService.generateContent(prompt);
      return response;
    } catch (e) {
      print('生成背景失败: $e');
      return '生成背景失败，请重试。';
    }
  }
} 