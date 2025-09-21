// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_constraint.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShiftConstraintAdapter extends TypeAdapter<ShiftConstraint> {
  @override
  final int typeId = 2;

  @override
  ShiftConstraint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShiftConstraint(
      id: fields[0] as String,
      staffId: fields[1] as String,
      date: fields[2] as DateTime,
      isAvailable: fields[3] as bool,
      reason: fields[4] as String?,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ShiftConstraint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.isAvailable)
      ..writeByte(4)
      ..write(obj.reason)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftConstraintAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
