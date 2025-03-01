import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'chapter.g.dart';

@HiveType(typeId: 2)
class Chapter {
  @HiveField(0)
  final int number;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String content;
  
  @HiveField(3)
  final String createTime;
  
  @HiveField(4)
  final String? id;
  
  @HiveField(5)
  final bool isSelected;
  
  Chapter({
    required this.number,
    required this.title,
    required this.content,
    String? createTime,
    this.id,
    this.isSelected = false,
  }) : createTime = createTime ?? DateTime.now().toString();
  
  Chapter copyWith({
    int? number,
    String? title,
    String? content,
    String? createTime,
    String? id,
    bool? isSelected,
  }) {
    return Chapter(
      number: number ?? this.number,
      title: title ?? this.title,
      content: content ?? this.content,
      createTime: createTime ?? this.createTime,
      id: id ?? this.id,
      isSelected: isSelected ?? this.isSelected,
    );
  }
  
  int get wordCount {
    return content.length;
  }
  
  @override
  String toString() {
    return 'Chapter{number: $number, title: $title, wordCount: $wordCount}';
  }
} 