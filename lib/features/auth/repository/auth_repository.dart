import 'package:firebase_auth/firebase_auth.dart';
import 'package:jot_it/core/services/google_auth_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/utils/l_printer.dart';

class AuthRepository {
  final GoogleAuthService authService;
  final LocalStorageService localStorageService;

  AuthRepository({required this.authService, required this.localStorageService});

  Future<User?> signInWithGoogle() async {
    try {
     return await authService.signInWithGoogle();
    } catch (e) {
      ZPrint("Login error: $e");
      return null;
    }
  }

  void signOut(){
    authService.signOut();
  }

  User? getCurrentUser(){
    return authService.currentUser;
  }

  bool getBiometricEnabled(){
    return localStorageService.getBiometricEnabled();

  }

  Future<void> saveBiometricEnabled(bool enabled) async{
    await localStorageService.saveBiometricEnabled(enabled);
  }

}
