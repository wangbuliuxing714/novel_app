import 'package:hive/hive.dart';
import 'package:novel_app/models/novel.dart';

class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final int typeId = 1;

  @override
  Chapter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chapter(
      number: fields[0] as int,
      title: fields[1] as String,
      content: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.number);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.content);
  }
} 