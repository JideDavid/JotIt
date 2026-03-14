
import 'package:jot_it/features/notes/model/note.dart';

import '../../features/auth/model/user_model.dart';

abstract class LocalStorageService {
  Future<void> saveToken(String token);
  String? getToken();
  Future<void> deleteToken();

  Future<void> saveUser(UserModel user);
  UserModel? getUser();
  Future<void> deleteUser();

  Future<void> saveNotes(List<Note> notes, String key);
  List<Note> getNotes(String key);
  Future<void> deleteNotes( String key );

  Future<void> clearAll();

  Future<void> saveBiometricEnabled(bool enabled);

  bool getBiometricEnabled();

  Future<void> saveAppLockChoice(bool choice);

  bool getAppLockChoice();

  Future<void> saveAppLockPin(String choice);

  String getAppLockPin();

}
