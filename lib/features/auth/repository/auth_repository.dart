import '../../../core/services/mock_auth_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/utils/l_printer.dart';
import '../model/user_model.dart';

class AuthRepository {
  final MockAuthService authService;
  final LocalStorageService localStorageService;

  AuthRepository({required this.authService, required this.localStorageService});

  Future<bool> login({
    required String email,
    required String pin,
  }) async {
    try {
      if (email.isEmpty || pin.isEmpty) {
        return false;
      }

      final resp = await authService.login(email, pin);

      final token = resp["token"];
      final user = UserModel.fromJson(resp["user"]);

      // Save to Hive
      await localStorageService.saveToken(token);
      await localStorageService.saveUser(user);

      return true; // ✅ success
    } catch (e) {
      ZPrint("Login error: $e");
      return false;
    }
  }


  String? getToken() {
    return localStorageService.getToken();
  }

  UserModel? getCurrentUser(){
    return localStorageService.getUser()!;
  }

  bool getBiometricEnabled(){
    return localStorageService.getBiometricEnabled();

  }

  saveBiometricEnabled(bool enabled) async{
    await localStorageService.saveBiometricEnabled(enabled);
  }

}
