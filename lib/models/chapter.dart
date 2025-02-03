class Chapter {
  final String id;
  String title;
  String content;
  bool isSelected;
  
  Chapter({
    required this.id,
    required this.title,
    this.content = '',
    this.isSelected = false,
  });
  
  // 从JSON反序列化
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? '',
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
  
  // 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'isSelected': isSelected,
    };
  }
} 