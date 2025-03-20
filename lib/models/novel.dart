import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'novel.g.dart';

@HiveType(typeId: 0)
class Novel {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  final String genre;
  
  @HiveField(3)
  String outline;
  
  @HiveField(4)
  String content;
  
  @HiveField(5)
  final List<Chapter> chapters;
  
  @HiveField(6)
  final DateTime createdAt;
  
  @HiveField(7)
  final DateTime? updatedAt;
  
  @HiveField(8)
  final String? style;

  String get createTime => createdAt.toString().split('.')[0];

  int get wordCount => content.replaceAll(RegExp(r'\s'), '').length;

  Novel({
    String? id,
    required this.title,
    required this.genre,
    required this.outline,
    required this.content,
    required this.chapters,
    required this.createdAt,
    this.updatedAt,
    this.style,
  }) : this.id = id ?? const Uuid().v4();

  Novel copyWith({
    String? title,
    String? genre,
    String? outline,
    String? content,
    List<Chapter>? chapters,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? style,
    String? id,
  }) {
    return Novel(
      title: title ?? this.title,
      genre: genre ?? this.genre,
      outline: outline ?? this.outline,
      content: content ?? this.content,
      chapters: chapters ?? this.chapters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      style: style ?? this.style,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'genre': genre,
    'outline': outline,
    'content': content,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'style': style,
  };

  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
    id: json['id'] as String,
    title: json['title'] as String,
    genre: json['genre'] as String,
    outline: json['outline'] as String,
    content: json['content'] as String,
    chapters: (json['chapters'] as List)
        .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
    style: json['style'] as String?,
  );

  Chapter get outlineChapter {
    return chapters.firstWhere(
      (chapter) => chapter.number == 0,
      orElse: () => Chapter(
        number: 0,
        title: '大纲',
        content: outline,
      ),
    );
  }

  void addOutlineAsChapter() {
    if (!chapters.any((chapter) => chapter.number == 0)) {
      chapters.insert(0, Chapter(
        number: 0,
        title: '大纲',
        content: outline,
      ));
    }
  }
}

@HiveType(typeId: 1)
class Chapter {
  @HiveField(0)
  final int number;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String content;

  int get index => number - 1;

  Chapter({
    required this.number,
    required this.title,
    required this.content,
  });

  Chapter copyWith({
    int? number,
    String? title,
    String? content,
  }) {
    return Chapter(
      number: number ?? this.number,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'content': content,
  };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    number: json['number'] as int,
    title: json['title'] as String,
    content: json['content'] as String,
  );
}