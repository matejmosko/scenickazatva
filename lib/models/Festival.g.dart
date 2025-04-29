// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Festival.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FestivalAdapter extends TypeAdapter<Festival> {
  @override
  final typeId = 1;

  @override
  Festival read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Festival(
      endDate: fields[0] as DateTime?,
      magazine_src: fields[1] == null
          ? "https://javisko.sk/wp-json/wp/v2/posts?per_page=20&order=desc&"
          : fields[1] as String,
      news_src: fields[2] == null
          ? "https://www.tvor-ba.sk/2024/wp-json/wp/v2/posts?per_page=20&order=desc&"
          : fields[2] as String,
      startDate: fields[3] as DateTime?,
      subtitle:
          fields[4] == null ? "Národné osvetové centrum" : fields[4] as String,
      title: fields[5] == null ? "Festivaly NOC" : fields[5] as String,
      backgroundColor: fields[6] == null ? "ffffffff" : fields[6] as String,
      foregroundColor: fields[7] == null ? "ff000000" : fields[7] as String,
      festivalBackgroundColor:
          fields[14] == null ? "ffffffff" : fields[14] as String,
      festivalForegroundColor:
          fields[15] == null ? "ff000000" : fields[15] as String,
      festivalThirdColor:
          fields[16] == null ? "ff000000" : fields[16] as String,
      selectedColor: fields[8] == null ? "ff888888" : fields[8] as String,
      mainProgramColor: fields[9] == null ? "ffffffff" : fields[9] as String,
      offProgramColor: fields[10] == null ? "ffffffff" : fields[10] as String,
      partnerProgramColor:
          fields[13] == null ? "ffffffff" : fields[13] as String,
      logo: fields[11] == null
          ? "gs://scenickazatva-343517.appspot.com/default.png"
          : fields[11] as String,
      background: fields[12] == null
          ? "gs://scenickazatva-343517.appspot.com/default.png"
          : fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Festival obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.endDate)
      ..writeByte(1)
      ..write(obj.magazine_src)
      ..writeByte(2)
      ..write(obj.news_src)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.subtitle)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.backgroundColor)
      ..writeByte(7)
      ..write(obj.foregroundColor)
      ..writeByte(8)
      ..write(obj.selectedColor)
      ..writeByte(9)
      ..write(obj.mainProgramColor)
      ..writeByte(10)
      ..write(obj.offProgramColor)
      ..writeByte(11)
      ..write(obj.logo)
      ..writeByte(12)
      ..write(obj.background)
      ..writeByte(13)
      ..write(obj.partnerProgramColor)
      ..writeByte(14)
      ..write(obj.festivalBackgroundColor)
      ..writeByte(15)
      ..write(obj.festivalForegroundColor)
      ..writeByte(16)
      ..write(obj.festivalThirdColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FestivalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
