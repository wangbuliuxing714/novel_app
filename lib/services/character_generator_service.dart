import 'package:get/get.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class CharacterGeneratorService extends GetxService {
  final AIService _aiService;
  final CharacterCardService _characterCardService;
  final CharacterTypeService _characterTypeService;
  final PromptPackageController _promptPackageController;
  
  CharacterGeneratorService(
    this._aiService,
    this._characterCardService,
    this._characterTypeService,
    this._promptPackageController,
  );
  
  Future<List<CharacterCard>> generateCharacters({
    required String title,
    required String genre,
    required String background,
    required int characterCount,
    List<CharacterType>? preferredTypes,
  }) async {
    // 获取角色提示词包
    final characterPrompt = _promptPackageController.getDefaultPromptPackage('character');
    final promptContent = characterPrompt?.content ?? '';
    
    // 构建生成角色的提示词
    final prompt = '''
你是一位专业的小说角色设计师，请为以下小说创建${characterCount}个丰满、立体的角色：

【小说信息】
- 标题：$title
- 类型：$genre
- 背景：$background

${preferredTypes != null && preferredTypes.isNotEmpty ? '【角色类型要求】\n' + preferredTypes.map((t) => '- ${t.name}：${t.description}').join('\n') : ''}

$promptContent

请为每个角色提供以下信息：
1. 基本信息：姓名、性别、年龄、种族
2. 外貌特征：体型描述、面部特征、服装风格、特殊配饰
3. 性格特征：主要性格特点、性格复杂性、性格形成原因
4. 背景故事：成长背景、重要生活经历、关键过去事件
5. 目标和动机：短期目标、长期目标、核心动机
6. 能力和技能：特殊能力、普通技能
7. 人际关系：家庭关系、朋友关系、敌人、爱情关系

请以JSON格式返回，格式如下：
```json
[
  {
    "name": "角色名",
    "gender": "性别",
    "age": "年龄",
    "race": "种族",
    "bodyDescription": "体型描述",
    "faceFeatures": "面部特征",
    "clothingStyle": "服装风格",
    "accessories": "特殊配饰",
    "personalityTraits": "主要性格特点",
    "personalityComplexity": "性格复杂性",
    "personalityFormation": "性格形成原因",
    "background": "成长背景",
    "lifeExperiences": "重要生活经历",
    "pastEvents": "关键过去事件",
    "shortTermGoals": "短期目标",
    "longTermGoals": "长期目标",
    "motivation": "核心动机",
    "specialAbilities": "特殊能力",
    "normalSkills": "普通技能",
    "familyRelations": "家庭关系",
    "friendships": "朋友关系",
    "enemies": "敌人",
    "loveInterests": "爱情关系"
  }
]
```

确保角色之间有明显的差异，并且角色特点与小说类型和背景相符。
''';

    try {
      // 调用AI服务生成角色
      final response = await _aiService.generateContent(prompt);
      
      // 解析JSON响应
      final jsonStr = _extractJsonFromResponse(response);
      final List<dynamic> charactersJson = jsonDecode(jsonStr);
      
      // 转换为CharacterCard对象
      final characters = charactersJson.map((json) {
        return CharacterCard(
          id: const Uuid().v4(),
          name: json['name'] ?? '未命名角色',
          characterTypeId: preferredTypes != null && preferredTypes.isNotEmpty 
              ? preferredTypes[0].id 
              : const Uuid().v4(),
          gender: json['gender'],
          age: json['age'],
          race: json['race'],
          bodyDescription: json['bodyDescription'],
          faceFeatures: json['faceFeatures'],
          clothingStyle: json['clothingStyle'],
          accessories: json['accessories'],
          personalityTraits: json['personalityTraits'],
          personalityComplexity: json['personalityComplexity'],
          personalityFormation: json['personalityFormation'],
          background: json['background'],
          lifeExperiences: json['lifeExperiences'],
          pastEvents: json['pastEvents'],
          shortTermGoals: json['shortTermGoals'],
          longTermGoals: json['longTermGoals'],
          motivation: json['motivation'],
          specialAbilities: json['specialAbilities'],
          normalSkills: json['normalSkills'],
          familyRelations: json['familyRelations'],
          friendships: json['friendships'],
          enemies: json['enemies'],
          loveInterests: json['loveInterests'],
        );
      }).toList();
      
      // 保存生成的角色
      for (var character in characters) {
        await _characterCardService.addCard(character);
      }
      
      return characters;
    } catch (e) {
      print('生成角色失败: $e');
      return [];
    }
  }
  
  String _extractJsonFromResponse(String response) {
    // 提取JSON字符串
    final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonRegex.firstMatch(response);
    
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    
    // 如果没有找到JSON标记，尝试直接解析
    if (response.trim().startsWith('[') && response.trim().endsWith(']')) {
      return response.trim();
    }
    
    throw Exception('无法从响应中提取JSON数据');
  }

  Future<List<CharacterCard>> generateCharactersFromJson(String jsonData) async {
    try {
      final List<dynamic> charactersJson = jsonDecode(jsonData);
      
      // 转换为CharacterCard对象，并指定一个默认的characterTypeId
      return charactersJson.map((json) => CharacterCard(
        id: const Uuid().v4(),
        name: json['name'] ?? '未命名角色',
        characterTypeId: const Uuid().v4(), // 使用新的UUID作为默认characterTypeId
        gender: json['gender'] ?? '',
        age: json['age'] ?? '',
        race: json['race'],
        bodyDescription: json['bodyDescription'] ?? '',
        faceFeatures: json['faceFeatures'],
        clothingStyle: json['clothingStyle'],
        accessories: json['accessories'],
        personalityTraits: json['personalityTraits'] ?? '',
        personalityComplexity: json['personalityComplexity'],
        personalityFormation: json['personalityFormation'],
        background: json['background'] ?? '',
        lifeExperiences: json['lifeExperiences'],
        pastEvents: json['pastEvents'],
        shortTermGoals: json['shortTermGoals'],
        longTermGoals: json['longTermGoals'],
        motivation: json['motivation'],
        specialAbilities: json['specialAbilities'],
        normalSkills: json['normalSkills'],
        familyRelations: json['familyRelations'],
        friendships: json['friendships'],
        enemies: json['enemies'],
        loveInterests: json['loveInterests'],
      )).toList();
    } catch (e) {
      print('解析JSON数据失败: $e');
      return [];
    }
  }
} 