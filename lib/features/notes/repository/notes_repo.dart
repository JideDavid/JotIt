import 'package:jot_it/core/services/local_storage_service.dart';
import 'package:jot_it/features/notes/model/note.dart';

class NotesRepo {
  final LocalStorageService localStorageService;
  NotesRepo({required this.localStorageService});

  Future<void> saveNotes(List<Note> notes, String key)async{
    await localStorageService.saveNotes(notes, key);
  }

  List<Note> getNotes(String key){
    return localStorageService.getNotes(key);
  }

  Future<void> deleteNotes(String key) async{
    localStorageService.deleteNotes(key);
  }
}