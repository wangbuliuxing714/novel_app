import 'package:get/get.dart';
import 'package:novel_app/models/prompt_package.dart';
import 'package:novel_app/services/prompt_package_service.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_app/prompts/master_prompts.dart';
import 'package:novel_app/prompts/male_prompts.dart';
import 'package:novel_app/prompts/female_prompts.dart';
import 'package:novel_app/prompts/short_novel_male_prompts.dart';
import 'package:novel_app/prompts/short_novel_female_prompts.dart';

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
  
  /// 获取短篇小说提示词内容
  String getShortNovelPromptContent(String type, String targetReader) {
    // 查找对应的提示词包
    final packages = getPromptPackagesByType(type);
    final packageName = targetReader == '女性向' 
      ? '短篇小说女性向提示词' 
      : '短篇小说男性向提示词';
      
    final package = packages.firstWhere(
      (p) => p.name == packageName,
      orElse: () => packages.firstWhere(
        (p) => p.isDefault,
        orElse: () => PromptPackage(
          id: '',
          name: '',
          description: '',
          type: type,
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

1. 【欲扬先抑，重点挖坑】：每个高潮前都必须先经历低谷，期待大高潮前往往应该有个小高潮，在这个小高潮后紧跟一个巨大低谷，这样更能衬托出高潮的壮观。挖坑是为了填坑，让读者产生强烈想要填坑的期待感。

2. 【节奏变化，保持韵律】：如果小说一直是直线剧情，会显得很无聊，就像听一首歌，如果节奏一直不变，就会很单调。小说应当像一首有起伏的歌曲，有高昂的副歌，也有舒缓的间奏。

3. 【递进原则，层层推进】：剧情发展应当有一种递进感，从轻到重，从浅到深，从个人到集体，从局部到整体，这样能让读者感受到故事在不断向前发展。

4. 【悬念设置，适度吊胃口】：每章结尾都应当设置一个小悬念，让读者想要继续看下去。但悬念不宜过多，也不应长期不解决，否则会让读者感到疲劳。

5. 【情感共鸣，角色成长】：让读者关心故事中的人物，关心他们的成长与命运，这种情感连接是最强的期待来源。角色应当有明显的成长弧线，让读者期待他们的改变。
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
    
    // 创建短篇小说男性向提示词包
    await createPromptPackage(
      name: '短篇小说男性向提示词',
      description: '针对男性读者的短篇小说提示词，优化节奏控制、人物塑造、世界观构建和叙事技巧',
      type: 'short_novel',
      content: ShortNovelMalePrompts.basicPrinciples + '\n\n' + ShortNovelMalePrompts.expectationPrompt,
      isDefault: true,
    );
    
    // 创建短篇小说女性向提示词包
    await createPromptPackage(
      name: '短篇小说女性向提示词',
      description: '针对女性读者的短篇小说提示词，注重情感节奏、人物塑造、关系网络和环境氛围',
      type: 'short_novel',
      content: ShortNovelFemalePrompts.basicPrinciples + '\n\n' + ShortNovelFemalePrompts.expectationPrompt,
      isDefault: false,
    );
  }
} 