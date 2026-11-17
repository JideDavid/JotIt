import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jot_it/core/services/internet_checker_service.dart';
import 'package:jot_it/core/services/local_biometric_service.dart';
import 'package:jot_it/core/services/local_storage_service.dart';
import 'package:jot_it/features/auth/repository/auth_repository.dart';
import 'package:jot_it/features/notes/model/note.dart';

Note makeNote(
  String id, {
  String? title,
  String body = '',
  int color = 0,
  bool isLocked = false,
  DateTime? timestamp,
  String? richText,
  String? paper,
  String? media,
}) {
  return Note(
    id: id,
    title: title ?? id,
    body: body,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1),
    color: color,
    isLocked: isLocked,
    richText: richText,
    paper: paper,
    media: media,
  );
}

void setBodyText(QuillController controller, String text) {
  controller.replaceText(
    0,
    controller.document.length - 1,
    text,
    TextSelection.collapsed(offset: text.length),
  );
}

class MemoryStorage extends Fake implements LocalStorageService {
  String? appearance;
  List<int> favoriteNoteColors = [];
  List<String> savedStyles = [];
  @override
  List<String> getSavedTextStyles() => List.of(savedStyles);
  @override
  Future<void> saveTextStyles(List<String> ids) async {
    if (failWrites) throw StateError('Disk unavailable');
    savedStyles = List.of(ids);
  }

  @override
  List<int> getFavoriteNoteColors() => List.of(favoriteNoteColors);

  @override
  Future<void> saveFavoriteNoteColors(List<int> colors) async {
    if (failWrites) throw StateError('Disk unavailable');
    await writeBarrier?.future;
    favoriteNoteColors = List.of(colors);
  }

  bool existingInstallation = false;

  @override
  String? getAppearance() => appearance;

  @override
  Future<void> saveAppearance(String mode) async {
    if (failWrites) throw StateError('Disk unavailable');
    await writeBarrier?.future;
    appearance = mode;
  }

  @override
  bool hasExistingData() => existingInstallation || notes.isNotEmpty || appLock;

  List<Note> notes = [];
  bool failWrites = false;
  bool failReads = false;
  int saveCalls = 0;
  Completer<void>? writeBarrier;
  bool appLock = false;
  bool biometric = false;
  String savedPin = '';
  String notePin = '';
  Completer<bool>? noteVerification;

  @override
  List<Note> getNotes(String key) {
    if (failReads) throw StateError('Disk unavailable');
    return List.of(notes);
  }

  @override
  Future<void> saveNotes(List<Note> notes, String key) async {
    saveCalls++;
    if (failWrites) throw StateError('Disk unavailable');
    await writeBarrier?.future;
    this.notes = List.of(notes);
  }

  @override
  Future<void> deleteNotes(String key) async {
    if (failWrites) throw StateError('Disk unavailable');
    await writeBarrier?.future;
    notes = [];
  }

  @override
  bool getAppLockChoice() => appLock;

  @override
  Future<void> saveAppLockChoice(bool choice) async {
    if (failWrites) throw StateError('Disk unavailable');
    appLock = choice;
    if (!choice) {
      biometric = false;
      savedPin = '';
    }
  }

  @override
  bool getBiometricEnabled() => biometric;

  @override
  Future<void> saveBiometricEnabled(bool enabled) async {
    if (failWrites) throw StateError('Disk unavailable');
    biometric = enabled;
  }

  @override
  Future<void> saveAppLockPin(String pin) async {
    if (failWrites) throw StateError('Disk unavailable');
    savedPin = pin;
  }

  @override
  Future<bool> verifyAppLockPin(String pin) async => pin == savedPin;

  @override
  bool hasNoteLockPin() => notePin.isNotEmpty;

  @override
  Future<void> createNoteLockPin(String pin) async {
    if (failWrites) throw StateError('Disk unavailable');
    if (hasNoteLockPin()) throw StateError('A note PIN already exists.');
    notePin = pin;
  }

  @override
  Future<bool> verifyNoteLockPin(String pin) async =>
      noteVerification?.future ?? Future.value(pin == notePin);
}

class TestAuthRepository extends Fake implements AuthRepository {
  TestAuthRepository(this.storage);
  final MemoryStorage storage;
  Completer<bool>? verification;
  int verificationCalls = 0;
  User? user;
  bool accountAvailable = true;
  String? unavailableReason;
  Stream<User?> accountChanges = const Stream.empty();
  Completer<User?>? signInResult;
  Completer<void>? signOutResult;
  Object? signInError;
  Object? signOutError;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isAccountAvailable => accountAvailable;

  @override
  String? get accountUnavailableReason => unavailableReason;

  @override
  User? getCurrentUser() => user;

  @override
  Stream<User?> get userChanges => accountChanges;

  @override
  Future<User?> signInWithGoogle() async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    return signInResult?.future ?? Future.value(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    await signOutResult?.future;
    user = null;
  }

  @override
  bool getAppLockChoice() => storage.appLock;

  @override
  Future<void> saveAppLockChoice(bool choice) =>
      storage.saveAppLockChoice(choice);

  @override
  bool getBiometricEnabled() => storage.biometric;

  @override
  Future<void> saveBiometricEnabled(bool enabled) =>
      storage.saveBiometricEnabled(enabled);

  @override
  Future<void> saveAppLockPin(String pin) => storage.saveAppLockPin(pin);

  @override
  Future<bool> verifyAppLockPin(String pin) async {
    verificationCalls++;
    if (verification != null) return verification!.future;
    return storage.verifyAppLockPin(pin);
  }
}

class TestBiometrics extends Fake implements LocalBiometricService {
  bool available = true;
  bool succeeds = true;
  int calls = 0;
  Completer<bool>? authentication;

  @override
  Future<bool> isBiometricAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    calls++;
    return authentication?.future ?? Future.value(succeeds);
  }
}

class TestConnection extends Fake implements InternetCheckerService {
  final controller = StreamController<bool>.broadcast();
  bool connected = true;

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get connectionStatusStream => controller.stream;

  @override
  void dispose() {
    controller.close();
  }
}
