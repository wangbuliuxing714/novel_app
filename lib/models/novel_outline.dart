import 'dart:convert';

class NovelOutline {
  final String novelTitle;
  final List<ChapterOutline> chapters;
  final String? outline;

  NovelOutline({
    required this.novelTitle,
    required this.chapters,
    this.outline,
  });

  factory NovelOutline.fromJson(Map<String, dynamic> json) {
    return NovelOutline(
      novelTitle: json['novel_title'] as String,
      chapters: (json['chapters'] as List)
          .map((e) => ChapterOutline.fromJson(e as Map<String, dynamic>))
          .toList(),
      outline: json['outline'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'novel_title': novelTitle,
    'chapters': chapters.map((e) => e.toJson()).toList(),
    'outline': outline,
  };

  static NovelOutline? tryParse(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      return NovelOutline.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}

class ChapterOutline {
  final int chapterNumber;
  final String chapterTitle;
  final String contentOutline;

  ChapterOutline({
    required this.chapterNumber,
    required this.chapterTitle,
    required this.contentOutline,
  });

  factory ChapterOutline.fromJson(Map<String, dynamic> json) {
    return ChapterOutline(
      chapterNumber: json['chapter_number'] as int,
      chapterTitle: json['chapter_title'] as String,
      contentOutline: json['content_outline'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapter_number': chapterNumber,
    'chapter_title': chapterTitle,
    'content_outline': contentOutline,
  };
} 