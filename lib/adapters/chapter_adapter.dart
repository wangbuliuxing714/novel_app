import 'package:hive/hive.dart';
import 'package:novel_app/models/novel.dart';

class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final int typeId = 1;

  @override
  Chapter read(BinaryReader reader) {
    return Chapter(
      number: reader.read(),
      title: reader.read(),
      content: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer.write(obj.number);
    writer.write(obj.title);
    writer.write(obj.content);
  }
} 