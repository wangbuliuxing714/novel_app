// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NovelAdapter extends TypeAdapter<Novel> {
  @override
  final int typeId = 1;

  @override
  Novel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Novel(
      title: fields[0] as String,
      genres: (fields[1] as List).cast<String>(),
      theme: fields[2] as String,
      targetReaders: fields[3] as String,
      outline: fields[4] as String,
      chapters: (fields[5] as List).cast<Chapter>(),
      createTime: fields[6] as String,
      wordCount: fields[7] as int,
      id: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Novel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.genres)
      ..writeByte(2)
      ..write(obj.theme)
      ..writeByte(3)
      ..write(obj.targetReaders)
      ..writeByte(4)
      ..write(obj.outline)
      ..writeByte(5)
      ..write(obj.chapters)
      ..writeByte(6)
      ..write(obj.createTime)
      ..writeByte(7)
      ..write(obj.wordCount)
      ..writeByte(8)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NovelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
