import 'package:hive/hive.dart';
import 'package:novel_app/models/novel.dart';

class NovelAdapter extends TypeAdapter<Novel> {
  @override
  final int typeId = 0;

  @override
  Novel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Novel(
      id: fields[0] as String?,
      title: fields[1] as String,
      genre: fields[2] as String,
      outline: fields[3] as String,
      content: fields[4] as String,
      chapters: (fields[5] as List).cast<Chapter>(),
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Novel obj) {
    writer.writeByte(7);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.genre);
    writer.writeByte(3);
    writer.write(obj.outline);
    writer.writeByte(4);
    writer.write(obj.content);
    writer.writeByte(5);
    writer.write(obj.chapters);
    writer.writeByte(6);
    writer.write(obj.createdAt);
  }
} 