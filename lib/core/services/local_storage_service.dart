
import '../../features/auth/model/user_model.dart';

abstract class LocalStorageService {
  Future<void> saveToken(String token);
  String? getToken();
  Future<void> deleteToken();

  Future<void> saveUser(UserModel user);
  UserModel? getUser();
  Future<void> deleteUser();

  Future<void> clearAll();

  Future<void> saveBiometricEnabled(bool enabled);

  bool getBiometricEnabled();

}
