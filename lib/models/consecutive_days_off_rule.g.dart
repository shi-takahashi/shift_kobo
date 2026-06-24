// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consecutive_days_off_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConsecutiveDaysOffRuleAdapter
    extends TypeAdapter<ConsecutiveDaysOffRule> {
  @override
  final int typeId = 3;

  @override
  ConsecutiveDaysOffRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConsecutiveDaysOffRule(
      length: fields[0] as int,
      count: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ConsecutiveDaysOffRule obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.length)
      ..writeByte(1)
      ..write(obj.count);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsecutiveDaysOffRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
