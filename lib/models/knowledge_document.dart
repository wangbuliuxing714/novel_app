import 'package:uuid/uuid.dart';

class KnowledgeDocument {
  final String id;
  String title;
  String content;
  String category;
  String? filePath;  // 上传文件的路径
  String? fileType;  // 文件类型
  final DateTime createdAt;
  DateTime updatedAt;

  KnowledgeDocument({
    String? id,
    required this.title,
    required this.content,
    required this.category,
    this.filePath,
    this.fileType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.id = id ?? const Uuid().v4(),
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'filePath': filePath,
    'fileType': fileType,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) => KnowledgeDocument(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    category: json['category'] as String,
    filePath: json['filePath'] as String?,
    fileType: json['fileType'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
} 