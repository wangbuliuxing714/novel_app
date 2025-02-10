import 'package:hive/hive.dart';
import 'package:novel_app/models/novel.dart';

class NovelAdapter extends TypeAdapter<Novel> {
  @override
  final int typeId = 0;

  @override
  Novel read(BinaryReader reader) {
    return Novel(
      id: reader.read(),
      title: reader.read(),
      genre: reader.read(),
      outline: reader.read(),
      content: reader.read(),
      chapters: (reader.read() as List).cast<Chapter>(),
      createdAt: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, Novel obj) {
    writer.write(obj.id);
    writer.write(obj.title);
    writer.write(obj.genre);
    writer.write(obj.outline);
    writer.write(obj.content);
    writer.write(obj.chapters);
    writer.write(obj.createdAt);
  }
} 