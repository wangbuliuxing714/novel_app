// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_package.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PromptPackageAdapter extends TypeAdapter<PromptPackage> {
  @override
  final int typeId = 10;

  @override
  PromptPackage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PromptPackage(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      type: fields[3] as String,
      content: fields[4] as String,
      isDefault: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PromptPackage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.isDefault)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptPackageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
