import 'package:hive/hive.dart';
import '../../../core/constants/z_strings.dart';
part 'user_model.g.dart';

@HiveType(typeId: ZStrings.userModelTypeId)
class UserModel {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String? email;

  @HiveField(2)
  final String? firstname;

  @HiveField(3)
  final String? surname;

  @HiveField(4)
  final String? image;


  UserModel({
    required this.id,
    required this.email,
    required this.firstname,
    required this.surname,
    required this.image,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      firstname: json['firstname'],
      surname: json['surname'],
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstname': firstname,
      'surname': surname,
      'image': image,
    };
  }
}
