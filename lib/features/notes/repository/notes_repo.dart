import 'package:jot_it/core/services/local_storage_service.dart';
import 'package:jot_it/features/notes/model/note.dart';

class NotesRepo {
  final LocalStorageService localStorageService;
  NotesRepo({required this.localStorageService});

  List<int> get favoriteColors => localStorageService.getFavoriteNoteColors();
  Future<void> saveFavoriteColors(List<int> colors) =>
      localStorageService.saveFavoriteNoteColors(colors);
  List<String> get savedTextStyles => localStorageService.getSavedTextStyles();
  Future<void> saveTextStyles(List<String> ids) =>
      localStorageService.saveTextStyles(ids);

  Future<void> saveNotes(List<Note> notes, String key) async {
    await localStorageService.saveNotes(notes, key);
  }

  List<Note> getNotes(String key) {
    final notes = List<Note>.of(localStorageService.getNotes(key));
    notes.sort(compareByUpdatedAt);
    return notes;
  }

  Future<void> deleteNotes(String key) async {
    await localStorageService.deleteNotes(key);
  }

  bool get hasNoteLockPin => localStorageService.hasNoteLockPin();

  Future<void> createNoteLockPin(String pin) =>
      localStorageService.createNoteLockPin(pin);

  Future<bool> verifyNoteLockPin(String pin) =>
      localStorageService.verifyNoteLockPin(pin);

  static int compareByUpdatedAt(Note first, Note second) {
    final order = second.timestamp.compareTo(first.timestamp);
    return order != 0 ? order : first.id.compareTo(second.id);
  }
}
