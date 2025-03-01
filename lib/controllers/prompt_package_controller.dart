import 'package:get/get.dart';
import 'package:novel_app/models/prompt_package.dart';
import 'package:novel_app/services/prompt_package_service.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_app/prompts/master_prompts.dart';
import 'package:novel_app/prompts/male_prompts.dart';
import 'package:novel_app/prompts/female_prompts.dart';

class PromptPackageController extends GetxController {
  final _promptPackageService = Get.find<PromptPackageService>();
  
  List<PromptPackage> get promptPackages => _promptPackageService.promptPackages;
  
  PromptPackage? getPromptPackage(String id) {
    return _promptPackageService.getPromptPackage(id);
  }
  
  List<PromptPackage> getPromptPackagesByType(String type) {
    return _promptPackageService.getPromptPackagesByType(type);
  }
  
  PromptPackage? getDefaultPromptPackage(String type) {
    return _promptPackageService.getDefaultPromptPackage(type);
  }
  
  Future<void> createPromptPackage({
    required String name,
    required String description,
    required String type,
    required String content,
    bool isDefault = false,
  }) async {
    final package = PromptPackage(
      id: const Uuid().v4(),
      name: name,
      description: description,
      type: type,
      content: content,
      isDefault: isDefault,
    );
    
    await _promptPackageService.savePromptPackage(package);
    
    if (isDefault) {
      await _promptPackageService.setDefaultPromptPackage(package.id);
    }
  }
  
  Future<void> updatePromptPackage({
    required String id,
    String? name,
    String? description,
    String? type,
    String? content,
    bool? isDefault,
  }) async {
    final package = _promptPackageService.getPromptPackage(id);
    if (package == null) return;
    
    final updatedPackage = package.copyWith(
      name: name,
      description: description,
      type: type,
      content: content,
      isDefault: isDefault,
    );
    
    await _promptPackageService.savePromptPackage(updatedPackage);
    
    if (isDefault == true) {
      await _promptPackageService.setDefaultPromptPackage(id);
    }
  }
  
  Future<void> deletePromptPackage(String id) async {
    await _promptPackageService.deletePromptPackage(id);
  }
  
  Future<void> setDefaultPromptPackage(String id) async {
    await _promptPackageService.setDefaultPromptPackage(id);
  }
  
  /// 获取当前提示词包内容
  String getCurrentPromptContent(String type) {
    final defaultPackage = getDefaultPromptPackage(type);
    return defaultPackage?.content ?? '';
  }
  
  /// 获取目标读者提示词内容
  String getTargetReaderPromptContent(String targetReader) {
    // 查找对应的提示词包
    final packages = getPromptPackagesByType('target_reader');
    final package = packages.firstWhere(
      (p) => p.name == (targetReader == '女性向' ? '女性向提示词' : '男性向提示词'),
      orElse: () => packages.firstWhere(
        (p) => p.isDefault,
        orElse: () => PromptPackage(
          id: '',
          name: '',
          description: '',
          type: 'target_reader',
          content: '',
        ),
      ),
    );
    return package.content;
  }
  
  // 创建一个基于期待感理论的提示词包
  Future<void> createExpectationPromptPackage() async {
    await createPromptPackage(
      name: '期待感提示词包',
      description: '基于期待感理论的提示词包，能够生成具有强烈期待感的小说内容',
      type: 'master',
      content: '''
在写网文的过程中，最重要的一件事就是保持期待感，它是一条把读者与故事连接起来的纽带。一本书如果在读者眼中失去了期待感，他们就会失去向下翻页的动力。

期待感是读者看书时产生的，想要看到剧情、人物接下来将会如何发展的一种感觉。包括读者想要看到剧情、人物按照自己的意愿发展，以及虽然不知道会如何发展，但潜意识里会想要看到某些东西，或者绝对不想看到某些东西的意愿。

在创作过程中，请遵循以下期待感原则：

1. 【展现价值】期待型：
   - 展示角色的能力或独特个性
   - 提供一个发挥能力的空间或背景
   - 展示对这个能力的迫切需求
   - 埋没角色的价值（受到轻视、压迫、冷落等）
   
2. 【矛盾冲突】期待型：
   - 构建相互依存的矛盾关系
   - 一个能力与一个不恰当的规则形成矛盾
   - 一个欲望与一个压力形成矛盾
   - 两个矛盾之间互相影响，形成期待

在创作大纲和章节内容时，请确保：
- 每个章节都包含至少一种期待感类型
- 主角的价值被埋没后，最终能够得到展现
- 矛盾冲突能够层层递进，不断升级
- 在关键情节点上，通过期待感的满足给读者带来情感共鸣

请记住，期待感的本质是让读者对故事中角色未能正确对待的价值产生期待，希望看到这种情况有所改变。
''',
      isDefault: true,
    );
  }
  
  Future<void> initDefaultPromptPackages() async {
    // 检查是否已经初始化
    if (promptPackages.isNotEmpty) {
      return;
    }
    
    // 创建默认的提示词包
    await createPromptPackage(
      name: '默认主提示词',
      description: '基础的AI写作原则和要求',
      type: 'master',
      content: MasterPrompts.basicPrinciples + '\n\n' + MasterPrompts.qualityControl,
      isDefault: true,
    );
    
    await createPromptPackage(
      name: '默认大纲提示词',
      description: '用于生成小说大纲的提示词',
      type: 'outline',
      content: MasterPrompts.outlineGenerationPrompt,
      isDefault: true,
    );
    
    await createPromptPackage(
      name: '默认章节提示词',
      description: '用于生成小说章节的提示词',
      type: 'chapter',
      content: MasterPrompts.chapterGenerationPrompt,
      isDefault: true,
    );
    
    await createPromptPackage(
      name: '期待感提示词',
      description: '用于生成具有强烈期待感的内容，让读者产生想要继续阅读的欲望',
      type: 'expectation',
      content: MasterPrompts.expectationPrompt,
      isDefault: true,
    );
    
    // 创建男性向提示词包
    await createPromptPackage(
      name: '男性向提示词',
      description: '针对男性读者的小说提示词，注重情节、冲突和成长',
      type: 'target_reader',
      content: MalePrompts.basicPrinciples + '\n\n' + MalePrompts.expectationPrompt,
      isDefault: true,
    );
    
    // 创建女性向提示词包
    await createPromptPackage(
      name: '女性向提示词',
      description: '针对女性读者的小说提示词，注重情感、关系和心理描写',
      type: 'target_reader',
      content: FemalePrompts.basicPrinciples + '\n\n' + FemalePrompts.expectationPrompt,
      isDefault: false,
    );
  }
} 