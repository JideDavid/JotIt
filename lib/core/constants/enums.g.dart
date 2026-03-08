// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccessMethodAdapter extends TypeAdapter<AccessMethod> {
  @override
  final int typeId = 100;

  @override
  AccessMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AccessMethod.busAccess;
      case 1:
        return AccessMethod.busDropOff;
      case 2:
        return AccessMethod.gatePickUp;
      case 3:
        return AccessMethod.gateDropOff;
      default:
        return AccessMethod.busAccess;
    }
  }

  @override
  void write(BinaryWriter writer, AccessMethod obj) {
    switch (obj) {
      case AccessMethod.busAccess:
        writer.writeByte(0);
        break;
      case AccessMethod.busDropOff:
        writer.writeByte(1);
        break;
      case AccessMethod.gatePickUp:
        writer.writeByte(2);
        break;
      case AccessMethod.gateDropOff:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VerificationMethodAdapter extends TypeAdapter<VerificationMethod> {
  @override
  final int typeId = 102;

  @override
  VerificationMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VerificationMethod.pin;
      case 1:
        return VerificationMethod.qR;
      default:
        return VerificationMethod.pin;
    }
  }

  @override
  void write(BinaryWriter writer, VerificationMethod obj) {
    switch (obj) {
      case VerificationMethod.pin:
        writer.writeByte(0);
        break;
      case VerificationMethod.qR:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerificationMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VerificationStateAdapter extends TypeAdapter<VerificationState> {
  @override
  final int typeId = 103;

  @override
  VerificationState read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return VerificationState.allowed;
      case 1:
        return VerificationState.denied;
      case 2:
        return VerificationState.offline;
      case 3:
        return VerificationState.pending;
      default:
        return VerificationState.allowed;
    }
  }

  @override
  void write(BinaryWriter writer, VerificationState obj) {
    switch (obj) {
      case VerificationState.allowed:
        writer.writeByte(0);
        break;
      case VerificationState.denied:
        writer.writeByte(1);
        break;
      case VerificationState.offline:
        writer.writeByte(2);
        break;
      case VerificationState.pending:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerificationStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
