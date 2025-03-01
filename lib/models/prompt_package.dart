import 'package:hive/hive.dart';

class PromptPackage {
  final String id;
  final String name;
  final String description;
  final String type; // outline, chapter, character, etc.
  final String content;
  final bool isDefault;
  final DateTime createdAt;
  
  PromptPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.content,
    this.isDefault = false,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();
  
  factory PromptPackage.fromJson(Map<String, dynamic> json) {
    return PromptPackage(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      content: json['content'],
      isDefault: json['isDefault'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'content': content,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  PromptPackage copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    String? content,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return PromptPackage(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      content: content ?? this.content,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 