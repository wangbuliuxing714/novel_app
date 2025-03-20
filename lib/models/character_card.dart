import 'package:get/get.dart';

class CharacterCard {
  final String id;
  final String name;
  final String characterTypeId;
  String gender;
  String age;
  String? race;
  
  // 外貌特征
  String bodyDescription;
  String? faceFeatures;
  String? clothingStyle;
  String? accessories;
  
  // 性格特征
  String personalityTraits;
  String? personalityComplexity;
  String? personalityFormation;
  
  // 背景故事
  String background;
  String? lifeExperiences;
  String? pastEvents;
  
  // 目标和动机
  String? shortTermGoals;
  String? longTermGoals;
  String? motivation;
  
  // 能力和技能
  String? specialAbilities;
  String? normalSkills;
  
  // 人际关系
  String? familyRelations;
  String? friendships;
  String? enemies;
  String? loveInterests;

  CharacterCard({
    required this.id,
    required this.name,
    required this.characterTypeId,
    this.gender = '',
    this.age = '',
    this.race,
    this.bodyDescription = '',
    this.faceFeatures,
    this.clothingStyle,
    this.accessories,
    this.personalityTraits = '',
    this.personalityComplexity,
    this.personalityFormation,
    this.background = '',
    this.lifeExperiences,
    this.pastEvents,
    this.shortTermGoals,
    this.longTermGoals,
    this.motivation,
    this.specialAbilities,
    this.normalSkills,
    this.familyRelations,
    this.friendships,
    this.enemies,
    this.loveInterests,
  });

  // 从JSON转换
  factory CharacterCard.fromJson(Map<String, dynamic> json) {
    return CharacterCard(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      characterTypeId: json['characterTypeId'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? '',
      race: json['race'] as String?,
      bodyDescription: json['bodyDescription'] ?? '',
      faceFeatures: json['faceFeatures'] as String?,
      clothingStyle: json['clothingStyle'] as String?,
      accessories: json['accessories'] as String?,
      personalityTraits: json['personalityTraits'] ?? '',
      personalityComplexity: json['personalityComplexity'] as String?,
      personalityFormation: json['personalityFormation'] as String?,
      background: json['background'] ?? '',
      lifeExperiences: json['lifeExperiences'] as String?,
      pastEvents: json['pastEvents'] as String?,
      shortTermGoals: json['shortTermGoals'] as String?,
      longTermGoals: json['longTermGoals'] as String?,
      motivation: json['motivation'] as String?,
      specialAbilities: json['specialAbilities'] as String?,
      normalSkills: json['normalSkills'] as String?,
      familyRelations: json['familyRelations'] as String?,
      friendships: json['friendships'] as String?,
      enemies: json['enemies'] as String?,
      loveInterests: json['loveInterests'] as String?,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'characterTypeId': characterTypeId,
      'gender': gender,
      'age': age,
      'race': race,
      'bodyDescription': bodyDescription,
      'faceFeatures': faceFeatures,
      'clothingStyle': clothingStyle,
      'accessories': accessories,
      'personalityTraits': personalityTraits,
      'personalityComplexity': personalityComplexity,
      'personalityFormation': personalityFormation,
      'background': background,
      'lifeExperiences': lifeExperiences,
      'pastEvents': pastEvents,
      'shortTermGoals': shortTermGoals,
      'longTermGoals': longTermGoals,
      'motivation': motivation,
      'specialAbilities': specialAbilities,
      'normalSkills': normalSkills,
      'familyRelations': familyRelations,
      'friendships': friendships,
      'enemies': enemies,
      'loveInterests': loveInterests,
    };
  }
} 