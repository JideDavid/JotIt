
import 'package:flutter/material.dart';
import 'package:jot_it/core/constants/colors.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';

import '../../../core/utils/l_printer.dart';
import '../../../core/utils/random_id_generator.dart';
import '../view/note_page.dart';

class NoteViewModel extends ChangeNotifier {
  final NotesRepo _notesRepo;
  NoteViewModel({required NotesRepo notesRepo}) : _notesRepo = notesRepo;

  List<Note> _allNotes = [];
  List<Note> get allNotes => _allNotes;

  Note? _openedNote;
  Note? get openedNote => _openedNote;


  TextEditingController titleController = TextEditingController();
  TextEditingController bodyController = TextEditingController();
  final List<Color> _colors = [
    ZColors.noteColor1,
    ZColors.noteColor2,
    ZColors.noteColor3,
    ZColors.noteColor4,
    ZColors.noteColor5,
    ZColors.noteColor6,
    ZColors.noteColor7,
    ZColors.noteColor8,
    ZColors.noteColor9,
  ];
  List<Color> get colors => _colors;

  int _selectedColor = 0;
  int get selectedColor => _selectedColor;

  void selectColor(int index){
   _selectedColor = index;
   notifyListeners();
  }

  void setColor(){
    if (_openedNote == null) {
      _selectedColor = 0;
      notifyListeners();
    } else {
      _selectedColor = _openedNote!.color;
      notifyListeners();
    }

  }

  void openNote(BuildContext context, Note? note){
    _openedNote = note;
    titleController.text = note?.title ?? '';
    bodyController.text = note?.body ?? '';
    setColor();
    notifyListeners();
    ZPrint('note opened');
    Navigator.push(context, MaterialPageRoute(builder: (context) => NotePage()));
  }

  Future<void> saveNote() async {
    if(titleController.text.isEmpty && bodyController.text.isEmpty){
      return;
    }

    if(_openedNote != null){
      // update note
      Note? note = getNoteById(_openedNote!.id);
      if(note == null) return;
      Note? updatedNote = Note(
          id: note.id,
          title: titleController.text,
          body: bodyController.text,
          timestamp: DateTime.now(),
          color: _selectedColor,
          isLocked: false
      );
      _allNotes.remove(note);
      _allNotes.add(updatedNote);
      _openedNote = updatedNote;
      _allNotes = await updateLocalStorage(_allNotes, "all");
      notifyListeners();
      ZPrint('note updated for notifier');
    }
    else{
      Note note = Note(
          id: RandomId().generate(),
          title: titleController.text,
          body: bodyController.text,
          timestamp: DateTime.now(),
          color: _selectedColor,
          isLocked: false);
      _allNotes.add(note);
      _openedNote = note;
      _allNotes = await updateLocalStorage(_allNotes, "all");
      notifyListeners();
      ZPrint('note saved for notifier');
    }
  }

  void deleteNote(String id){
    Note? note = getNoteById(id);
    if(note == null) return;
    _allNotes.remove(note);
    notifyListeners();
    ZPrint('note deleted');
  }

  void setOpenedNote(Note? note){
    _openedNote = note;
    titleController.text = note?.title ?? '';
    bodyController.text = note?.body ?? '';
    notifyListeners();
    ZPrint('note opened');
  }

  bool isUpdated(){
    // if note is null and title and body are empty
    if(_openedNote == null && titleController.text.isEmpty && bodyController.text.isEmpty) return true;

    // if note is not null and title or body are empty
    if(_openedNote == null && titleController.text.isEmpty || _openedNote == null && bodyController.text.isEmpty) return false;

    Note? note = getNoteById(_openedNote!.id);

    if(note == null) return true;

    if(note.title == titleController.text && note.body == bodyController.text){
      return true;
    }
    return false;
  }

  Note? getNoteById(String id) {
    try {
      return _allNotes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null; // note not found
    }
  }

  Future<List<Note>> updateLocalStorage(List<Note> notes, String key) async{
    await _notesRepo.saveNotes(notes, key);
    return _notesRepo.getNotes(key);
  }

  Future<void> getNotesFromLocalStorage() async{
    ZPrint("getting all notes from local");
    _allNotes = _notesRepo.getNotes("all");
    notifyListeners();
    ZPrint("all noted retrieved from local");

  }

}
