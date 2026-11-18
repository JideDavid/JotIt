import 'package:hive/hive.dart';
import 'package:jot_it/features/notes/model/note.dart';
import '../../features/auth/model/user_model.dart';
import '../constants/z_strings.dart';
import '../utils/l_printer.dart';
import 'local_storage_service.dart';
import 'pin_hasher.dart';
import 'note_pin_record.dart';
import '../../features/notes/model/note_card_color.dart';

class HiveLocalStorageService implements LocalStorageService {
  static const _noteLockPinKey = 'note_lock_pin';
  final Box _authBox;
  final Box _noteBox;
  Future<void> _noteWrites = Future<void>.value();
  void Function()? onNotesChanged;

  Map<String, dynamic> readNoteEnvelope(String key) {
    final raw = _noteBox.get(key);
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : {'notes': List<Note>.from(raw as List? ?? const [])};
  }

  /// Local edits and sync acknowledgement share one queue and one Hive record.
  /// A failed disk write cannot advance only the sync baseline.
  Future<void> updateNoteEnvelope(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) {
    final write = _noteWrites.then((_) async {
      final record = update(readNoteEnvelope(key));
      await _noteBox.put(key, record);
      if (key == 'all') onNotesChanged?.call();
    });
    _noteWrites = write.catchError((Object _) {});
    return write;
  }

  HiveLocalStorageService(this._authBox, this._noteBox);

  @override
  List<String> getSavedTextStyles() =>
      (_authBox.get('saved_text_styles') as List? ?? const [])
          .whereType<String>()
          .toList();

  @override
  Future<void> saveTextStyles(List<String> ids) =>
      _authBox.put('saved_text_styles', ids.toSet().take(100).toList());

  @override
  List<int> getFavoriteNoteColors() =>
      NoteCardColor.favoritesFrom(_authBox.get('favorite_note_colors'));

  @override
  Future<void> saveFavoriteNoteColors(List<int> colors) async {
    if (colors.length > NoteCardColor.maxFavorites ||
        colors.any((color) => !NoteCardColor.isCustom(color))) {
      throw ArgumentError('Invalid favorite colors.');
    }
    await _authBox.put('favorite_note_colors', colors.toSet().toList());
  }

  @override
  String? getAppearance() {
    final value = _authBox.get('appearance');
    return value is String ? value : null;
  }

  @override
  Future<void> saveAppearance(String mode) async {
    if (!['system', 'light', 'dark'].contains(mode)) {
      throw ArgumentError('Invalid appearance mode.');
    }
    await _authBox.put('appearance', mode);
  }

  @override
  bool hasExistingData() => _authBox.isNotEmpty || _noteBox.isNotEmpty;

  @override
  Future<void> saveToken(String token) async {
    await _authBox.put(ZStrings.tokenKey, token);
    ZPrint("Token saved to local db");
  }

  @override
  String? getToken() {
    String? val = _authBox.get(ZStrings.tokenKey);
    ZPrint("Token retrieved from local db");
    return val;
  }

  @override
  Future<void> deleteToken() async {
    await _authBox.delete(ZStrings.tokenKey);
    ZPrint("Token deleted from local db");
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _authBox.put(ZStrings.userKey, user);
    ZPrint("User saved to local db: ${user.firstname}");
  }

  @override
  Future<void> deleteUser() async {
    await _authBox.delete(ZStrings.userKey);
    ZPrint("User deleted from local db");
  }

  @override
  UserModel? getUser() {
    UserModel? val = _authBox.get(ZStrings.userKey);
    if (val == null) return null;
    ZPrint("User retrieved from local db: ${val.firstname}");
    return val;
  }

  @override
  Future<void> saveNotes(List<Note> notes, key) async {
    await updateNoteEnvelope(
      key,
      (record) => {...record, 'notes': List<Note>.of(notes)},
    );
    ZPrint("Notes saved to local db");
  }

  @override
  List<Note> getNotes(String key) {
    final notes = List<Note>.from(readNoteEnvelope(key)['notes'] as List);
    ZPrint("Notes retrieved from local db: ${notes.length}");
    return notes;
  }

  @override
  Future<void> deleteNotes(String key) async {
    await updateNoteEnvelope(key, (record) => {...record, 'notes': <Note>[]});
    ZPrint("Notes deleted from local db");
  }

  @override
  Future<void> clearAll() async {
    await _authBox.clear();
    await _noteBox.clear();
    ZPrint("All data cleared from local db");
  }

  @override
  Future<void> saveBiometricEnabled(bool enabled) async {
    await _authBox.put(ZStrings.biometricEnabledKey, enabled);
    ZPrint("Biometric enabled saved as $enabled");
  }

  @override
  bool getBiometricEnabled() {
    final bool enabled = _authBox.get(
      ZStrings.biometricEnabledKey,
      defaultValue: false,
    );
    return enabled;
  }

  @override
  Future<void> saveAppLockChoice(bool choice) async {
    if (choice) {
      final pin =
          _authBox.get(ZStrings.appLockPinKey, defaultValue: '') as String;
      if (pin.isEmpty) throw StateError('Set a PIN before enabling App Lock.');
      await _authBox.put(ZStrings.appLockKey, true);
    } else {
      await _authBox.putAll({
        ZStrings.appLockKey: false,
        ZStrings.biometricEnabledKey: false,
        ZStrings.appLockPinKey: '',
      });
    }
    ZPrint("App lock enabled saved as $choice");
  }

  @override
  bool getAppLockChoice() {
    final bool choice = _authBox.get(ZStrings.appLockKey, defaultValue: false);
    return choice;
  }

  @override
  Future<void> saveAppLockPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain four digits.');
    }
    final hashedPin = await PinHasher().hash(pin);
    await _authBox.put(ZStrings.appLockPinKey, hashedPin);
  }

  @override
  Future<bool> verifyAppLockPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) return false;
    final saved =
        _authBox.get(ZStrings.appLockPinKey, defaultValue: '') as String;
    if (RegExp(r'^\d{4}$').hasMatch(saved)) {
      if (pin != saved) return false;
      await saveAppLockPin(pin);
      return true;
    }
    return PinHasher().verify(pin, saved);
  }

  @override
  bool hasNoteLockPin() => _authBox.get(_noteLockPinKey) != null;

  @override
  Future<void> createNoteLockPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain four digits.');
    }
    if (hasNoteLockPin()) throw StateError('A note PIN already exists.');
    final encoded = await PinHasher().hash(pin);
    if (hasNoteLockPin()) throw StateError('A note PIN already exists.');
    await _authBox.put(_noteLockPinKey, encoded);
  }

  @override
  Future<bool> verifyNoteLockPin(String pin) async {
    final encoded = notePinHash(_authBox.get(_noteLockPinKey));
    return PinHasher().verify(pin, encoded);
  }
}
