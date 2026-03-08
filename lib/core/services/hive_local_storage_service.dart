import 'package:hive/hive.dart';
import '../../features/auth/model/user_model.dart';
import '../constants/z_strings.dart';
import '../utils/l_printer.dart';
import 'local_storage_service.dart';

class HiveLocalStorageService implements LocalStorageService {
  final Box _authBox;

  HiveLocalStorageService(this._authBox,);

  @override
  Future<void> saveToken(String token) async{
    await _authBox.put(ZStrings.tokenKey, token);
    ZPrint("Token saved: $token");
  }

  @override
  String? getToken() {
    String? val = _authBox.get(ZStrings.tokenKey);
    ZPrint("Token retrieved: $val");
    return val;
  }

  @override
  Future<void> deleteToken() async{
    await _authBox.delete(ZStrings.tokenKey);
    ZPrint("Token deleted");
  }

  @override
  Future<void> saveUser(UserModel user) async{
    await _authBox.put(ZStrings.userKey, user);
    ZPrint("User saved: ${user.firstname}");
  }

  @override
  UserModel? getUser() {
    UserModel? val = _authBox.get(ZStrings.userKey);
    if(val == null) return null;
    ZPrint("User retrieved: ${val.firstname}");
    return val;
  }

  @override
  Future<void> deleteUser() async{
    await _authBox.delete(ZStrings.userKey);
    ZPrint("User deleted");
  }

  @override
  Future<void> clearAll() async{
    await _authBox.clear();
    ZPrint("All data cleared");
  }

  @override
  Future<void> saveBiometricEnabled(bool enabled) async{
    await _authBox.put(ZStrings.biometricEnabledKey, enabled);
    ZPrint("Biometric enabled saved: $enabled}");
  }

  @override
  bool getBiometricEnabled() {
    final bool enabled = _authBox.get(ZStrings.biometricEnabledKey,defaultValue: false);
    return enabled;
  }
}
