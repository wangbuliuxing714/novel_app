class Novel {
  final String id;
  final String title;
  final String genre;
  final String outline;
  String content;
  final List<Chapter> chapters;
  final DateTime createdAt;

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
  }) : this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'genre': genre,
    'outline': outline,
    'content': content,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
    id: json['id'] as String?,
    title: json['title'] as String,
    genre: json['genre'] as String,
    outline: json['outline'] as String,
    content: json['content'] as String,
    chapters: (json['chapters'] as List)
        .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class Chapter {
  final int number;
  final String title;
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