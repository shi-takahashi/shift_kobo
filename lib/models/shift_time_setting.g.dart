// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_time_setting.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShiftTimeSettingAdapter extends TypeAdapter<ShiftTimeSetting> {
  @override
  final int typeId = 5;

  @override
  ShiftTimeSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShiftTimeSetting(
      shiftType: fields[0] as ShiftType,
      startTime: fields[1] as String,
      endTime: fields[2] as String,
      isActive: fields[3] as bool,
      customName: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShiftTimeSetting obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.shiftType)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.customName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftTimeSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShiftTypeAdapter extends TypeAdapter<ShiftType> {
  @override
  final int typeId = 4;

  @override
  ShiftType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ShiftType.shift1;
      case 1:
        return ShiftType.shift2;
      case 2:
        return ShiftType.shift3;
      case 3:
        return ShiftType.shift4;
      case 4:
        return ShiftType.shift5;
      case 5:
        return ShiftType.shift6;
      case 6:
        return ShiftType.shift7;
      case 7:
        return ShiftType.shift8;
      case 8:
        return ShiftType.shift9;
      case 9:
        return ShiftType.shift10;
      default:
        return ShiftType.shift1;
    }
  }

  @override
  void write(BinaryWriter writer, ShiftType obj) {
    switch (obj) {
      case ShiftType.shift1:
        writer.writeByte(0);
        break;
      case ShiftType.shift2:
        writer.writeByte(1);
        break;
      case ShiftType.shift3:
        writer.writeByte(2);
        break;
      case ShiftType.shift4:
        writer.writeByte(3);
        break;
      case ShiftType.shift5:
        writer.writeByte(4);
        break;
      case ShiftType.shift6:
        writer.writeByte(5);
        break;
      case ShiftType.shift7:
        writer.writeByte(6);
        break;
      case ShiftType.shift8:
        writer.writeByte(7);
        break;
      case ShiftType.shift9:
        writer.writeByte(8);
        break;
      case ShiftType.shift10:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
