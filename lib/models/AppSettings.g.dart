// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppSettings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 0;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      defaultfestival: fields[0] == null ? "sutaze" : fields[0] as String,
      festivals: fields[1] == null
          ? const {}
          : (fields[1] as Map).cast<String, Festival>(),
      fontSizeFactor: fields[2] == null ? 1.0 : fields[2] as double,
      notificationsEnabled: fields[3] == null ? true : fields[3] as bool,
      remindersEnabled: fields[4] == null ? true : fields[4] as bool,
      lastMagazinePostId: fields[5] == null ? 0 : fields[5] as int,
      interceptLinks: fields[6] == null ? true : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.defaultfestival)
      ..writeByte(1)
      ..write(obj.festivals)
      ..writeByte(2)
      ..write(obj.fontSizeFactor)
      ..writeByte(3)
      ..write(obj.notificationsEnabled)
      ..writeByte(4)
      ..write(obj.remindersEnabled)
      ..writeByte(5)
      ..write(obj.lastMagazinePostId)
      ..writeByte(6)
      ..write(obj.interceptLinks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
