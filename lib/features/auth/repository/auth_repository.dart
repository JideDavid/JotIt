import 'package:firebase_auth/firebase_auth.dart';
import 'package:jot_it/core/services/google_auth_service.dart';
import '../../../core/services/local_storage_service.dart';

class AuthRepository {
  final GoogleAuthService authService;
  final LocalStorageService localStorageService;

  AuthRepository({
    required this.authService,
    required this.localStorageService,
  });

  bool get isAccountAvailable => authService.isAvailable;
  String? get accountUnavailableReason => authService.unavailableReason;
  Stream<User?> get userChanges => authService.userChanges;

  Future<User?> signInWithGoogle() => authService.signInWithGoogle();

  Future<void> signOut() async {
    await authService.signOut();
  }

  User? getCurrentUser() {
    return authService.currentUser;
  }

  bool getBiometricEnabled() {
    return localStorageService.getBiometricEnabled();
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    await localStorageService.saveBiometricEnabled(enabled);
  }

  bool getAppLockChoice() {
    return localStorageService.getAppLockChoice();
  }

  Future<void> saveAppLockChoice(bool choice) async {
    await localStorageService.saveAppLockChoice(choice);
  }

  Future<bool> verifyAppLockPin(String pin) {
    return localStorageService.verifyAppLockPin(pin);
  }

  Future<void> saveAppLockPin(String pin) async {
    await localStorageService.saveAppLockPin(pin);
  }
}
