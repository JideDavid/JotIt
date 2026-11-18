import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:jot_it/core/constants/colors.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import '../../../core/utils/random_id_generator.dart';
import '../model/note_paper.dart';
import '../model/note_attachment.dart';
import '../model/note_card_color.dart';
import '../model/note_sticker.dart';
import '../model/note_text_style.dart';
import '../services/note_document_edits.dart';
import '../view/note_page.dart';

class NoteViewModel extends ChangeNotifier {
  final NotesRepo _notesRepo;
  final DateTime Function() _now;

  NoteViewModel({required NotesRepo notesRepo, DateTime Function()? now})
    : _notesRepo = notesRepo,
      _now = now ?? DateTime.now {
    searchController.addListener(searchNotes);
  }

  List<Note> _allNotes = [];
  List<Note> get allNotes => List.unmodifiable(_allNotes);

  List<Note> get visibleNotes {
    final query = searchController.text.trim().toLowerCase();
    return List.unmodifiable(
      _allNotes.where((note) {
        if (note.isLocked) return query.isEmpty;
        return note.title.toLowerCase().contains(query) ||
            note.body.toLowerCase().contains(query);
      }),
    );
  }

  bool get hasSearchQuery => searchController.text.trim().isNotEmpty;

  Note? _openedNote;
  Note? get openedNote => _openedNote;

  bool _editorActive = false;
  bool get cloudCanSync =>
      !_disposed &&
      _foreground &&
      !_editorActive &&
      !_isSaving &&
      !_changingNoteLock &&
      !_loadFailed;
  bool _openedNoteUnlocked = false;
  bool get needsNoteUnlock =>
      _editorActive && (_openedNote?.isLocked ?? false) && !_openedNoteUnlocked;
  bool get hasNoteLockPin => _notesRepo.hasNoteLockPin;
  Future<bool> verifyNotePinForRecovery(String pin) =>
      _authenticateNotePin(pin, allowSetup: false);
  void revokeNotePinSessions() {
    _lockGeneration++;
    _openedNoteUnlocked = false;
    _failedPinAttempts = 0;
    _pinRetryAt = null;
    if (!_disposed) notifyListeners();
  }

  bool _changingNoteLock = false;
  bool get changingNoteLock => _changingNoteLock;
  bool _verifyingNotePin = false;
  bool _foreground = true;
  int _lockGeneration = 0;
  int _failedPinAttempts = 0;
  DateTime? _pinRetryAt;
  String? _noteLockError;
  String? get noteLockError => _noteLockError;

  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _foreground = false;
      _lockGeneration++;
      _openedNoteUnlocked = false;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
    }
  }

  Future<bool> _authenticateNotePin(
    String pin, {
    bool allowSetup = false,
  }) async {
    if (_verifyingNotePin || !_foreground) return false;
    _noteLockError = null;
    if (_pinRetryAt != null && _now().isBefore(_pinRetryAt!)) {
      _noteLockError = 'Too many attempts. Try again in 30 seconds.';
      return false;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      _noteLockError = 'Enter a four-digit PIN.';
      return false;
    }
    final generation = _lockGeneration;
    _verifyingNotePin = true;
    try {
      if (!hasNoteLockPin && allowSetup) {
        await _notesRepo.createNoteLockPin(pin);
      } else if (!await _notesRepo.verifyNoteLockPin(pin)) {
        _failedPinAttempts++;
        if (_failedPinAttempts >= 5) {
          _failedPinAttempts = 0;
          _pinRetryAt = _now().add(const Duration(seconds: 30));
          _noteLockError = 'Too many attempts. Try again in 30 seconds.';
        } else {
          _noteLockError = 'Incorrect note PIN.';
        }
        return false;
      }
      if (_disposed || generation != _lockGeneration || !_foreground) {
        _noteLockError = 'Please enter the PIN again.';
        return false;
      }
      _failedPinAttempts = 0;
      _pinRetryAt = null;
      return true;
    } catch (_) {
      _noteLockError = 'Could not verify the note PIN. Please try again.';
      return false;
    } finally {
      _verifyingNotePin = false;
    }
  }

  Future<bool> unlockOpenedNote(String pin) async {
    if (!await _authenticateNotePin(pin, allowSetup: true)) return false;
    _openedNoteUnlocked = true;
    if (!_disposed) notifyListeners();
    return true;
  }

  Future<bool> changeOpenedNoteLock(String pin, {required bool locked}) async {
    if (_changingNoteLock || _isSaving || _loadFailed) return false;
    _changingNoteLock = true;
    final generation = _lockGeneration;
    notifyListeners();
    try {
      if (!await _authenticateNotePin(pin, allowSetup: locked)) return false;
      final saved = await _saveNote(locked: locked);
      if (!saved) {
        _noteLockError = errorMessage;
        return false;
      }
      _openedNoteUnlocked = generation == _lockGeneration && _foreground;
      return true;
    } finally {
      _changingNoteLock = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _isSaving = false;
  bool get isSaving => _isSaving;
  String? _errorMessage;
  String? get errorMessage => _loadFailed
      ? 'Could not load notes. Reload notes before saving.'
      : _errorMessage;
  bool _disposed = false;
  bool _loadFailed = false;

  final searchController = TextEditingController();
  final titleController = TextEditingController();
  final bodyController = QuillController.basic();
  String _savedBodyDelta = '[{"insert":"\\n"}]';

  String get bodyText {
    final text = bodyController.document
        .toDelta()
        .toJson()
        .map((op) {
          final insert = op['insert'];
          if (insert is String) return insert;
          final sticker = NoteSticker.fromInsert(insert);
          return sticker == null
              ? ''
              : '${sticker.text} ${sticker.body}'.trim();
        })
        .join()
        .replaceAll('\uFFFC', '');
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  }

  String get _bodyDelta =>
      jsonEncode(bodyController.document.toDelta().toJson());
  final List<Color> colors = const [
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

  List<String>? _savedStyles;
  List<String> get savedTextStyles =>
      List.unmodifiable(_savedStyles ??= _notesRepo.savedTextStyles);
  bool _savingStyle = false;
  Future<bool> toggleSavedTextStyle(String id) async {
    if (_savingStyle || NoteTextStyles.find(id) == null) return false;
    final ids = List<String>.of(savedTextStyles);
    if (!ids.remove(id)) ids.add(id);
    _savingStyle = true;
    try {
      await _notesRepo.saveTextStyles(ids);
      _savedStyles = ids;
      if (!_disposed) notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _savingStyle = false;
    }
  }

  List<PlacedSticker> get stickers =>
      NoteDocumentEdits.stickers(bodyController.document);

  bool applyTextStyle(
    NoteTextStyle style,
    TextSelection selection, {
    bool write = false,
  }) {
    if (!canMoveAttachments) return false;
    NoteTextStyles.apply(bodyController, style, selection, write: write);
    notifyListeners();
    return true;
  }

  bool insertSticker(
    StickerFormat format, {
    TextSelection? selection,
    bool free = false,
    int color = 0xffe9af35,
    double x = .3,
    double dy = 0,
  }) {
    if (!canMoveAttachments || stickers.length >= 100) return false;
    final sticker = NoteSticker(
      id: RandomId().generate(),
      formatId: format.id,
      text: format.text,
      body: format.body,
      color: color,
      width: format.width,
      free: free,
      x: x.clamp(0, 1),
      dy: dy.clamp(-5000, 5000),
    );
    NoteDocumentEdits.insert(
      bodyController,
      sticker,
      (selection ?? bodyController.selection).extentOffset,
    );
    notifyListeners();
    return true;
  }

  bool updateSticker(String id, NoteSticker? sticker) {
    if (!canMoveAttachments) return false;
    final updated = NoteDocumentEdits.update(bodyController, id, sticker);
    if (updated) notifyListeners();
    return updated;
  }

  bool moveSticker(String id, int target, NoteSticker replacement) {
    if (!canMoveAttachments) return false;
    final moved = NoteDocumentEdits.move(
      bodyController,
      id,
      target,
      replacement,
    );
    if (moved) notifyListeners();
    return moved;
  }

  /// Apply only to the exact document the user reviewed. The entire proposal
  /// belongs to one native undo transaction, including stickers and doodles.
  bool applyAiProposal(
    Document expectedDocument,
    Delta original,
    Delta proposed,
  ) {
    if (!canMoveAttachments ||
        !identical(expectedDocument, bodyController.document) ||
        jsonEncode(original.toJson()) != _bodyDelta) {
      return false;
    }
    // Diff the content separately: matching an earlier newline to Quill's
    // mandatory final newline can otherwise produce an illegal append after it.
    final originalLength = original.toList().fold<int>(
      0,
      (n, op) => n + (op.length ?? 0),
    );
    final proposedLength = proposed.toList().fold<int>(
      0,
      (n, op) => n + (op.length ?? 0),
    );
    var change = original
        .slice(0, originalLength - 1)
        .diff(proposed.slice(0, proposedLength - 1));
    final before = original.toList().last.attributes ?? <String, dynamic>{};
    final after = proposed.toList().last.attributes ?? <String, dynamic>{};
    final attributes = <String, dynamic>{
      for (final key in {...before.keys, ...after.keys})
        if (before[key] != after[key]) key: after[key],
    };
    if (attributes.isNotEmpty) {
      change = change.compose(
        Delta()
          ..retain(proposedLength - 1)
          ..retain(1, attributes),
      );
    }
    if (change.isEmpty) return true;
    NoteDocumentEdits.compose(
      bodyController,
      change,
      bodyController.selection.extentOffset.clamp(0, proposedLength - 1),
    );
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> saveGeneratedNote(Delta proposed, String title) async {
    if (!canMoveAttachments || _loadFailed) return false;
    final document = Document.fromDelta(proposed);
    try {
      final plain = document.toPlainText().replaceAll('\uFFFC', '').trim();
      final stickers = NoteDocumentEdits.stickers(document);
      if (plain.isEmpty && stickers.isEmpty) return false;
      // Generated notes cannot import media references from another note.
      if (proposed.toJson().any(
        (op) =>
            op['insert'] is! String &&
            NoteSticker.fromInsert(op['insert']) == null,
      )) {
        return false;
      }
      final note = Note(
        id: RandomId().generate(),
        title: title.trim().isEmpty ? 'New AI note' : title.trim(),
        body: [
          plain,
          ...stickers.map((s) => '${s.sticker.text} ${s.sticker.body}'),
        ].where((s) => s.trim().isNotEmpty).join('\n'),
        richText: jsonEncode(proposed.toJson()),
        timestamp: _now(),
        color: 0,
        isLocked: false,
      );
      // Persist independently so the current editor and its unsaved work stay intact.
      return _persist([..._allNotes, note]);
    } finally {
      document.close();
    }
  }

  int _selectedColor = 0;
  int get selectedColor => _selectedColor;
  List<int>? _favoriteColors;
  List<int> get favoriteColors =>
      List.unmodifiable(_favoriteColors ??= _notesRepo.favoriteColors);
  bool _savingFavorite = false;

  Future<bool> toggleFavoriteColor(int color) async {
    if (_savingFavorite || !NoteCardColor.isCustom(color)) return false;
    final updated = List<int>.of(favoriteColors);
    if (!updated.remove(color)) updated.add(color);
    if (updated.length > NoteCardColor.maxFavorites) return false;
    _savingFavorite = true;
    try {
      await _notesRepo.saveFavoriteColors(updated);
      _favoriteColors = updated;
      if (!_disposed) notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _savingFavorite = false;
    }
  }

  NotePaper _paper = const NotePaper();
  NotePaper get paper => _paper;

  final Map<String, NoteAttachment> _draftAttachments = {};
  String? _unreadableMedia;

  List<NoteAttachment> get attachments {
    final identifiers = bodyController.document
        .toDelta()
        .toJson()
        .map((operation) => NoteAttachment.embeddedId(operation['insert']))
        .whereType<String>()
        .toSet();
    return List.unmodifiable(
      _draftAttachments.values.where((item) => identifiers.contains(item.id)),
    );
  }

  NoteAttachment? attachmentById(String id) => _draftAttachments[id];

  bool get canMoveAttachments =>
      !_isSaving &&
      !_changingNoteLock &&
      !((_openedNote?.isLocked ?? false) && !_openedNoteUnlocked) &&
      _foreground;

  /// Move the existing embed and its paragraph in one undoable change.
  /// [targetOffset] belongs to the document before the move.
  bool moveAttachment(String id, int targetOffset) {
    if (!canMoveAttachments || attachmentById(id) == null) return false;
    final document = bodyController.document;
    final original = document.toDelta();
    var source = 0;
    var found = false;
    for (final operation in original.toJson()) {
      final insert = operation['insert'];
      if (NoteAttachment.embeddedId(insert) == id) {
        found = true;
        break;
      }
      source += insert is String ? insert.length : 1;
    }
    if (!found) return false;
    final text = document.toPlainText();
    final ownLine =
        (source == 0 || text[source - 1] == '\n') && text[source + 1] == '\n';
    // Quill must always retain its terminal newline.
    final length = ownLine && source + 2 < document.length ? 2 : 1;
    final target = targetOffset.clamp(0, document.length - 1);
    if (target >= source && target <= source + length) return false;
    final destination = target > source ? target - length : target;
    final deletion = Delta()
      ..retain(source)
      ..delete(length);
    final remainingText = text.replaceRange(source, source + length, '');
    final leadingBreak =
        destination > 0 && remainingText[destination - 1] != '\n';
    final line = document.queryChild(target).node;
    final insertion = Delta()..retain(destination);
    if (leadingBreak) {
      insertion.insert('\n', line is Line ? line.style.toJson() : null);
    }
    for (final operation in original.slice(source, source + 1).toList()) {
      insertion.push(operation);
    }
    insertion.insert('\n');
    final change = deletion.compose(insertion);
    // Keep relocation separate from typing, and undo both halves together.
    document.history.lastRecorded = 0;
    bodyController.compose(
      change,
      bodyController.selection,
      ChangeSource.local,
    );
    bodyController.updateSelection(
      TextSelection.collapsed(
        offset: (destination + (leadingBreak ? 1 : 0) + 2).clamp(
          0,
          document.length - 1,
        ),
      ),
      ChangeSource.local,
    );
    document.history.lastRecorded = 0;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  bool attachMedia(NoteAttachment attachment, {TextSelection? selection}) {
    if (_isSaving ||
        _changingNoteLock ||
        ((_openedNote?.isLocked ?? false) && !_openedNoteUnlocked) ||
        !_foreground) {
      return false;
    }
    final current = attachments;
    if (_draftAttachments.containsKey(attachment.id)) {
      _errorMessage = 'This attachment is already in the note.';
      notifyListeners();
      return false;
    }
    if (_unreadableMedia != null) {
      _errorMessage =
          'Existing media could not be read. It has been preserved; reopen the note before adding more.';
      notifyListeners();
      return false;
    }
    if (attachment.bytes.isEmpty ||
        attachment.bytes.length > NoteAttachment.maxFileBytes ||
        !NoteAttachment.mimeTypes.values.contains(attachment.mimeType)) {
      _errorMessage = 'Choose a supported, non-empty file smaller than 5 MB.';
      notifyListeners();
      return false;
    }
    if (current.length >= NoteAttachment.maxAttachments ||
        current.fold<int>(0, (total, item) => total + item.bytes.length) +
                attachment.bytes.length >
            NoteAttachment.maxNoteBytes) {
      _errorMessage =
          'A note can hold up to 12 attachments and 20 MB of media.';
      notifyListeners();
      return false;
    }
    _draftAttachments[attachment.id] = attachment;
    bodyController.document.history.lastRecorded = 0;
    final offset = (selection ?? bodyController.selection).extentOffset.clamp(
      0,
      bodyController.document.length - 1,
    );
    final text = bodyController.document.toPlainText();
    final needsLeadingBreak = offset > 0 && text[offset - 1] != '\n';
    final line = bodyController.document.queryChild(offset).node;
    final insertion = Delta();
    if (needsLeadingBreak) {
      insertion.insert('\n', line is Line ? line.style.toJson() : null);
    }
    insertion
      ..insert({NoteAttachment.embedType: attachment.id})
      ..insert('\n');
    bodyController.replaceText(offset, 0, insertion, null);
    bodyController.updateSelection(
      TextSelection.collapsed(
        offset: (offset + 2 + (needsLeadingBreak ? 1 : 0)).clamp(
          0,
          bodyController.document.length - 1,
        ),
      ),
      ChangeSource.local,
    );
    bodyController.document.history.lastRecorded = 0;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  void removeAttachmentAt(int offset) {
    if (_isSaving ||
        _changingNoteLock ||
        ((_openedNote?.isLocked ?? false) && !_openedNoteUnlocked) ||
        !_foreground) {
      return;
    }
    var position = 0;
    for (final operation in bodyController.document.toDelta().toJson()) {
      final insert = operation['insert'];
      if (position == offset && NoteAttachment.embeddedId(insert) != null) {
        bodyController.document.history.lastRecorded = 0;
        bodyController.replaceText(
          offset,
          1,
          '',
          TextSelection.collapsed(offset: offset),
        );
        bodyController.document.history.lastRecorded = 0;
        notifyListeners();
        return;
      }
      position += insert is String ? insert.length : 1;
    }
  }

  void selectPaper(NotePaper paper) {
    if (_paper == paper) return;
    _paper = paper;
    notifyListeners();
  }

  bool get hasUnsavedChanges {
    final note = _openedNote;
    if (note == null) {
      return titleController.text.isNotEmpty ||
          bodyText.isNotEmpty ||
          attachments.isNotEmpty ||
          stickers.isNotEmpty ||
          _selectedColor != 0 ||
          _paper != const NotePaper();
    }
    return note.title != titleController.text ||
        _bodyDelta != _savedBodyDelta ||
        note.color != _selectedColor ||
        NotePaper.decode(note.paper) != _paper;
  }

  void selectColor(int index) {
    if (!NoteCardColor.isValid(index) || _changingNoteLock || needsNoteUnlock) {
      return;
    }
    _selectedColor = index;
    notifyListeners();
  }

  void searchNotes() {
    notifyListeners();
  }

  Future<void> openNote(BuildContext context, Note? note) async {
    if (_isSaving || _changingNoteLock || _editorActive) return;
    setOpenedNote(note);
    _editorActive = true;
    notifyListeners();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotePage()),
    );
    _editorActive = false;
    if (!_disposed) setOpenedNote(null);
  }

  Future<bool> saveNote() async {
    if (_changingNoteLock ||
        ((_openedNote?.isLocked ?? false) && !_openedNoteUnlocked)) {
      return false;
    }
    return _saveNote();
  }

  Future<bool> _saveNote({bool? locked}) async {
    if (_isSaving || _loadFailed) return false;
    if (titleController.text.trim().isEmpty &&
        bodyText.trim().isEmpty &&
        attachments.isEmpty &&
        stickers.isEmpty) {
      _errorMessage = 'Enter a title or some note text.';
      notifyListeners();
      return false;
    }
    if (!hasUnsavedChanges &&
        (locked == null || locked == _openedNote?.isLocked)) {
      return true;
    }

    final note = Note(
      id: _openedNote?.id ?? RandomId().generate(),
      title: titleController.text,
      body: bodyText,
      richText: _bodyDelta,
      paper: _paper.encode(),
      media: _unreadableMedia ?? NoteAttachment.encodeAll(attachments),
      timestamp: _now(),
      color: _selectedColor,
      isLocked: locked ?? _openedNote?.isLocked ?? false,
    );
    final notes = _allNotes.where((saved) => saved.id != note.id).toList()
      ..add(note);
    return _persist(notes, savedNote: note);
  }

  Future<bool> deleteNote(String id, {String? pin}) async {
    if (_isSaving || _loadFailed || _changingNoteLock) return false;
    if (!_allNotes.any((note) => note.id == id)) return true;
    final note = _allNotes.firstWhere((note) => note.id == id);
    if (note.isLocked) {
      if (pin == null || !await _authenticateNotePin(pin, allowSetup: true)) {
        return false;
      }
      if (_isSaving || _changingNoteLock || _loadFailed) return false;
    }
    final notes = _allNotes.where((note) => note.id != id).toList();
    return _persist(notes);
  }

  Future<bool> _persist(List<Note> notes, {Note? savedNote}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _notesRepo.saveNotes(notes, 'all');
      _allNotes = List<Note>.of(notes)..sort(NotesRepo.compareByUpdatedAt);
      if (savedNote != null) {
        _openedNote = savedNote;
        _savedBodyDelta = savedNote.richText!;
      }
      return true;
    } catch (_) {
      _errorMessage = 'Could not save changes. Please try again.';
      return false;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  void setOpenedNote(Note? note) {
    _lockGeneration++;
    _openedNoteUnlocked = false;
    _openedNote = note;
    _draftAttachments
      ..clear()
      ..addEntries(
        NoteAttachment.decodeAll(
          note?.media,
        ).map((item) => MapEntry(item.id, item)),
      );
    _unreadableMedia = note?.media != null && _draftAttachments.isEmpty
        ? note!.media
        : null;
    titleController.text = note?.title ?? '';
    Document? document;
    if (note?.richText != null) {
      try {
        document = Document.fromJson(jsonDecode(note!.richText!) as List);
      } catch (_) {
        document = null;
      }
    }
    if (document == null && _draftAttachments.isNotEmpty) {
      document = Document.fromJson([
        {'insert': '${note?.body ?? ''}\n'},
        for (final attachment in _draftAttachments.values) ...[
          {
            'insert': {NoteAttachment.embedType: attachment.id},
          },
          {'insert': '\n'},
        ],
      ]);
    }
    final previousDocument = bodyController.document;
    bodyController.document =
        document ??
        Document.fromJson([
          {'insert': '${note?.body ?? ''}\n'},
        ]);
    previousDocument.close();
    bodyController.forceToggledStyle(const Style());
    _savedBodyDelta = _bodyDelta;
    _selectedColor = NoteCardColor.normalize(note?.color ?? 0);
    _paper = NotePaper.decode(note?.paper);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> getNotesFromLocalStorage() async {
    try {
      _allNotes = _notesRepo.getNotes('all');
      _loadFailed = false;
      _errorMessage = null;
    } catch (_) {
      _loadFailed = true;
      _errorMessage = 'Could not load notes. Please try again.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    searchController.dispose();
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }
}
