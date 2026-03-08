
import 'package:flutter/material.dart';
import 'package:jot_it/core/constants/colors.dart';
import 'package:jot_it/features/notes/model/note_model.dart';

import '../../../core/utils/l_printer.dart';
import '../../../core/utils/random_id_generator.dart';
import '../view/note_page.dart';

class NoteViewModel extends ChangeNotifier {
  final List<NoteModel> _allNotes = [];
  List<NoteModel> get allNotes => _allNotes;

  NoteModel? _openedNote;
  NoteModel? get openedNote => _openedNote;


  TextEditingController titleController = TextEditingController();
  TextEditingController bodyController = TextEditingController();


  void openNote(BuildContext context, NoteModel? note){
    _openedNote = note;
    titleController.text = note?.title ?? '';
    bodyController.text = note?.body ?? '';
    notifyListeners();
    ZPrint('note opened');
    Navigator.push(context, MaterialPageRoute(builder: (context) => NotePage()));
  }

  void saveNote(){
    if(titleController.text.isEmpty && bodyController.text.isEmpty){
      return;
    }

    if(_openedNote != null){
      // update note
      NoteModel? note = getNoteById(_openedNote!.id);
      if(note == null) return;
      NoteModel? updatedNote = NoteModel(
          id: note.id,
          title: titleController.text,
          body: bodyController.text,
          timestamp: DateTime.now(),
          color: ZColors.defaultNoteColor,
          isLocked: false
      );
      _allNotes.remove(note);
      _allNotes.add(updatedNote);
      _openedNote = updatedNote;
      notifyListeners();
    }
    else{
      NoteModel note = NoteModel(
          id: RandomId().generate(),
          title: titleController.text,
          body: bodyController.text,
          timestamp: DateTime.now(),
          color: ZColors.defaultNoteColor,
          isLocked: false);
      _allNotes.add(note);
      _openedNote = note;
      notifyListeners();
    }

    ZPrint('note saved');
  }

  void deleteNote(String id){
    NoteModel? note = getNoteById(id);
    if(note == null) return;
    _allNotes.remove(note);
    notifyListeners();
    ZPrint('note deleted');
  }

  void setOpenedNote(NoteModel? note){
    _openedNote = note;
    titleController.text = note?.title ?? '';
    bodyController.text = note?.body ?? '';
    notifyListeners();
    ZPrint('note opened');
  }

  bool isUpdated(){
    if(_openedNote == null && titleController.text.isEmpty && bodyController.text.isEmpty) return true;

    if(_openedNote == null && titleController.text.isEmpty || _openedNote == null && bodyController.text.isEmpty) return false;

    NoteModel? note = getNoteById(_openedNote!.id);

    if(note == null) return true;

    if(note.title == titleController.text && note.body == bodyController.text){
      return true;
    }
    return false;
  }

  NoteModel? getNoteById(String id) {
    try {
      return _allNotes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null; // note not found
    }
  }

}
