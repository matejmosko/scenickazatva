// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Ad.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdAdapter extends TypeAdapter<Ad> {
  @override
  final typeId = 4;

  @override
  Ad read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ad(
      title: fields[0] == null ? "" : fields[0] as String,
      description: fields[1] == null ? "" : fields[1] as String,
      image: fields[2] == null ? "" : fields[2] as String,
      link: fields[3] == null ? "" : fields[3] as String,
      cta: fields[4] == null ? "" : fields[4] as String,
      show: fields[5] == null ? false : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Ad obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.image)
      ..writeByte(3)
      ..write(obj.link)
      ..writeByte(4)
      ..write(obj.cta)
      ..writeByte(5)
      ..write(obj.show);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
