import 'package:hive/hive.dart';
import 'package:jot_it/features/notes/model/note.dart';
import '../../features/auth/model/user_model.dart';
import '../constants/z_strings.dart';
import '../utils/l_printer.dart';
import 'local_storage_service.dart';

class HiveLocalStorageService implements LocalStorageService {
  final Box _authBox;
  final Box _noteBox;

  HiveLocalStorageService(this._authBox, this._noteBox);

  @override
  Future<void> saveToken(String token) async{
    await _authBox.put(ZStrings.tokenKey, token);
    ZPrint("Token saved from local db: $token");
  }

  @override
  String? getToken() {
    String? val = _authBox.get(ZStrings.tokenKey);
    ZPrint("Token retrieved from local db: $val");
    return val;
  }

  @override
  Future<void> deleteToken() async{
    await _authBox.delete(ZStrings.tokenKey);
    ZPrint("Token deleted from local db");
  }

  @override
  Future<void> saveUser(UserModel user) async{
    await _authBox.put(ZStrings.userKey, user);
    ZPrint("User saved to local db: ${user.firstname}");
  }

  @override
  Future<void> deleteUser() async{
    await _authBox.delete(ZStrings.userKey);
    ZPrint("User deleted from local db");
  }

  @override
  UserModel? getUser() {
    UserModel? val = _authBox.get(ZStrings.userKey);
    if(val == null) return null;
    ZPrint("User retrieved from local db: ${val.firstname}");
    return val;
  }

  @override
  Future<void> saveNotes(List<Note> notes, key) async{
    await _noteBox.put(key, notes);
    ZPrint("Notes saved to local db");
  }

  @override
  List<Note> getNotes(String key) {
    List<Note> notes = (_noteBox.get(key, defaultValue: []) as List).cast<Note>();
    notes = notes.reversed.toList();
    ZPrint("Notes retrieved from local db: ${notes.length}");
    return notes;
  }

  @override
  Future<void> deleteNotes(String key) async{
    await _authBox.delete(key);
    ZPrint("User deleted from local db");
  }

  @override
  Future<void> clearAll() async{
    await _authBox.clear();
    ZPrint("All data cleared from local db");
  }

  @override
  Future<void> saveBiometricEnabled(bool enabled) async{
    await _authBox.put(ZStrings.biometricEnabledKey, enabled);
    ZPrint("Biometric enabled saved as $enabled");
  }

  @override
  bool getBiometricEnabled() {
    final bool enabled = _authBox.get(ZStrings.biometricEnabledKey,defaultValue: false);
    return enabled;
  }

  @override
  Future<void> saveAppLockChoice(bool choice) async{
    await _authBox.put(ZStrings.appLockKey, choice);
    ZPrint("App lock enabled saved as $choice");
  }

  @override
  bool getAppLockChoice() {
    final bool choice = _authBox.get(ZStrings.appLockKey, defaultValue: false);
    return choice;
  }

  @override
  Future<void> saveAppLockPin(String pin) async{
    await _authBox.put(ZStrings.appLockPinKey, pin);
    ZPrint("App lock pin saved as $pin");
  }

  @override
  String getAppLockPin() {
    final String pin = _authBox.get(ZStrings.appLockPinKey, defaultValue: "");
    return pin;
  }
}
