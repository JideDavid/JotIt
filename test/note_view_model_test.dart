import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'support/fakes.dart';

void main() {
  late MemoryStorage storage;
  late NotesRepo repository;
  late NoteViewModel viewModel;

  setUp(() {
    storage = MemoryStorage();
    repository = NotesRepo(localStorageService: storage);
    var timestamp = DateTime.utc(2026, 11, 13);
    viewModel = NoteViewModel(
      notesRepo: repository,
      now: () {
        final current = timestamp;
        timestamp = timestamp.add(const Duration(seconds: 1));
        return current;
      },
    );
  });
  tearDown(() => viewModel.dispose());

  test(
    'new title and body are dirty and save without dereferencing a null note',
    () async {
      expect(viewModel.hasUnsavedChanges, false);
      viewModel.titleController.text = 'Shopping';
      setBodyText(viewModel.bodyController, 'Rice and beans');
      expect(viewModel.hasUnsavedChanges, true);
      expect(await viewModel.saveNote(), true);
      expect(storage.notes.single.title, 'Shopping');
      expect(viewModel.hasUnsavedChanges, false);
    },
  );

  test('title-only and body-only notes can be saved', () async {
    viewModel.titleController.text = 'Title only';
    expect(await viewModel.saveNote(), true);
    viewModel.setOpenedNote(null);
    setBodyText(viewModel.bodyController, 'Body only');
    expect(await viewModel.saveNote(), true);
    expect(storage.notes, hasLength(2));
  });

  test('blank notes are rejected without writing', () async {
    viewModel.titleController.text = '   ';
    setBodyText(viewModel.bodyController, '\n');
    expect(await viewModel.saveNote(), false);
    expect(storage.saveCalls, 0);
    expect(viewModel.errorMessage, isNotNull);
  });

  test('color-only changes save and preserve note lock metadata', () async {
    final note = makeNote('private', isLocked: true);
    storage.notes = [note];
    await viewModel.getNotesFromLocalStorage();
    viewModel.setOpenedNote(note);
    storage.notePin = '1234';
    expect(await viewModel.unlockOpenedNote('1234'), true);
    viewModel.selectColor(2);
    expect(viewModel.hasUnsavedChanges, true);
    expect(await viewModel.saveNote(), true);
    expect(storage.notes.single.color, 2);
    expect(storage.notes.single.isLocked, true);
    expect(viewModel.hasUnsavedChanges, false);
  });

  test('clearing existing text remains an unsaved change', () {
    viewModel.setOpenedNote(makeNote('existing', body: 'Keep this'));
    viewModel.titleController.clear();
    setBodyText(viewModel.bodyController, '');
    expect(viewModel.hasUnsavedChanges, true);
  });

  test(
    'failed saves keep the draft and allow retry without duplicating notes',
    () async {
      viewModel.titleController.text = 'Draft';
      storage.failWrites = true;
      expect(await viewModel.saveNote(), false);
      expect(viewModel.openedNote, isNull);
      expect(viewModel.allNotes, isEmpty);
      expect(viewModel.titleController.text, 'Draft');
      expect(viewModel.hasUnsavedChanges, true);
      storage.failWrites = false;
      expect(await viewModel.saveNote(), true);
      expect(storage.notes, hasLength(1));
    },
  );

  test('failed updates preserve the previously saved version', () async {
    final original = makeNote('original');
    storage.notes = [original];
    await viewModel.getNotesFromLocalStorage();
    viewModel.setOpenedNote(original);
    viewModel.titleController.text = 'Changed';
    storage.failWrites = true;
    expect(await viewModel.saveNote(), false);
    expect(viewModel.allNotes.single.title, 'original');
    expect(viewModel.openedNote, same(original));
    expect(viewModel.hasUnsavedChanges, true);
  });

  test(
    'pending save rejects duplicate writes and preserves newer typing',
    () async {
      storage.writeBarrier = Completer<void>();
      viewModel.titleController.text = 'First draft';
      final saving = viewModel.saveNote();
      expect(viewModel.isSaving, true);
      expect(await viewModel.saveNote(), false);
      expect(viewModel.allNotes, isEmpty);
      viewModel.titleController.text = 'Newer draft';
      storage.writeBarrier!.complete();
      expect(await saving, true);
      expect(storage.saveCalls, 1);
      expect(storage.notes.single.title, 'First draft');
      expect(viewModel.hasUnsavedChanges, true);
      expect(await viewModel.saveNote(), true);
      expect(storage.notes.single.title, 'Newer draft');
    },
  );

  test('failed deletion retains the note in memory and on disk', () async {
    storage.notes = [makeNote('keep')];
    await viewModel.getNotesFromLocalStorage();
    storage.failWrites = true;
    expect(await viewModel.deleteNote('keep'), false);
    expect(viewModel.allNotes.single.id, 'keep');
    expect(storage.notes.single.id, 'keep');
  });

  test(
    'deletion is not reported as complete before persistence finishes',
    () async {
      storage.notes = [makeNote('remove')];
      await viewModel.getNotesFromLocalStorage();
      storage.writeBarrier = Completer<void>();
      final deleting = viewModel.deleteNote('remove');
      expect(viewModel.allNotes, hasLength(1));
      storage.writeBarrier!.complete();
      expect(await deleting, true);
      expect(viewModel.allNotes, isEmpty);
    },
  );

  test(
    'notes stay newest first across edits and reloads, with stable ties',
    () async {
      storage.notes = [
        makeNote('older'),
        makeNote('newer', timestamp: DateTime.utc(2026, 2, 1)),
        makeNote('another'),
      ];
      await viewModel.getNotesFromLocalStorage();
      expect(viewModel.allNotes.map((note) => note.id), [
        'newer',
        'another',
        'older',
      ]);
      viewModel.setOpenedNote(viewModel.allNotes.last);
      setBodyText(viewModel.bodyController, 'Edited');
      await viewModel.saveNote();
      expect(viewModel.allNotes.map((note) => note.id), [
        'older',
        'newer',
        'another',
      ]);
      await viewModel.getNotesFromLocalStorage();
      expect(viewModel.allNotes.map((note) => note.id), [
        'older',
        'newer',
        'another',
      ]);
      viewModel.setOpenedNote(null);
      viewModel.titleController.text = 'Fresh';
      await viewModel.saveNote();
      expect(viewModel.allNotes.map((note) => note.title).skip(1), [
        'older',
        'newer',
        'another',
      ]);
    },
  );

  test('search returns no results for a nonmatching query', () async {
    storage.notes = [makeNote('one')];
    await viewModel.getNotesFromLocalStorage();
    viewModel.searchController.text = 'missing';
    expect(viewModel.visibleNotes, isEmpty);
    viewModel.searchController.clear();
    expect(viewModel.visibleNotes.single.id, 'one');
  });

  test(
    'search matches title and body and refreshes after edits and deletes',
    () async {
      storage.notes = [
        makeNote('one', title: 'Shopping'),
        makeNote('two', body: 'shopping list'),
      ];
      await viewModel.getNotesFromLocalStorage();
      viewModel.searchController.text = ' SHOPPING ';
      expect(viewModel.visibleNotes, hasLength(2));
      viewModel.setOpenedNote(viewModel.visibleNotes.first);
      viewModel.titleController.text = 'Different';
      await viewModel.saveNote();
      expect(viewModel.visibleNotes.single.id, 'two');
      await viewModel.deleteNote('two');
      expect(viewModel.visibleNotes, isEmpty);
    },
  );

  test('repository deletion awaits storage and propagates failure', () async {
    storage.writeBarrier = Completer<void>();
    var complete = false;
    final deleting = repository.deleteNotes('all').then((_) => complete = true);
    await Future<void>.delayed(Duration.zero);
    expect(complete, false);
    storage.writeBarrier!.complete();
    await deleting;
    expect(complete, true);
    storage.failWrites = true;
    await expectLater(repository.deleteNotes('all'), throwsStateError);
  });

  test(
    'a failed load cannot overwrite existing notes with an empty collection',
    () async {
      storage.notes = [makeNote('existing')];
      storage.failReads = true;
      await viewModel.getNotesFromLocalStorage();
      viewModel.setOpenedNote(null);
      viewModel.titleController.text = 'New draft';
      expect(await viewModel.saveNote(), false);
      expect(await viewModel.deleteNote('existing'), false);
      expect(storage.saveCalls, 0);
      expect(viewModel.errorMessage, contains('Reload notes'));
      expect(storage.notes.single.id, 'existing');
      storage.failReads = false;
      await viewModel.getNotesFromLocalStorage();
      expect(await viewModel.saveNote(), true);
      expect(storage.notes, hasLength(2));
    },
  );
}
