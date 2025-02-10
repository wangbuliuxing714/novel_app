class CharacterType {
  final String id;
  final String name;
  final String description;
  final String color; // 用于UI显示的颜色代码

  CharacterType({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
  });

  // 从JSON转换
  factory CharacterType.fromJson(Map<String, dynamic> json) {
    return CharacterType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      color: json['color'] as String,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
    };
  }
} 