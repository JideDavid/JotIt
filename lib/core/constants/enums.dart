import 'package:hive/hive.dart';
import 'z_strings.dart';

part 'enums.g.dart';

  @HiveType(typeId: ZStrings.accessMethodId)
  enum AccessMethod{
  @HiveField(0)
  busAccess, 
  
  @HiveField(1)
  busDropOff, 
  
  @HiveField(2)
  gatePickUp, 
  
  @HiveField(3)
  gateDropOff}

  @HiveType(typeId: ZStrings.verificationMethodId)
  enum VerificationMethod{

  @HiveField(0)
  pin, 
  
  @HiveField(1)
  qR,}

  @HiveType(typeId: ZStrings.verificationStateId)
  enum VerificationState{

  @HiveField(0)
  allowed,

  @HiveField(1)
  denied,

  @HiveField(2)
  offline,

  @HiveField(3)
  pending}