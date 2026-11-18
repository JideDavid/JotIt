import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'support/fakes.dart';

void main() {
  late MemoryStorage storage;
  late NoteViewModel notes;
  late DateTime now;

  setUp(() {
    storage = MemoryStorage();
    now = DateTime.utc(2026, 11, 13);
    notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: storage),
      now: () => now,
    );
  });
  tearDown(() => notes.dispose());
  test(
    'recovery verification does not unlock notes and reset revokes access without losing drafts',
    () async {
      storage.notePin = '1234';
      final original = makeNote('private', isLocked: true, body: 'Saved');
      storage.notes = [original];
      notes.setOpenedNote(original);
      expect(await notes.verifyNotePinForRecovery('1234'), true);
      expect(notes.canMoveAttachments, false);
      expect(await notes.saveNote(), false);
      expect(await notes.unlockOpenedNote('1234'), true);
      setBodyText(notes.bodyController, 'Unsaved draft');
      notes.revokeNotePinSessions();
      expect(notes.canMoveAttachments, false);
      expect(await notes.saveNote(), false);
      expect(notes.bodyController.document.toPlainText(), 'Unsaved draft\n');
      expect(storage.notes.single, same(original));
      expect(storage.notes.single.isLocked, true);
    },
  );

  test(
    'first lock saves the draft and creates one shared PIN for later notes',
    () async {
      notes.titleController.text = 'Private';
      setBodyText(notes.bodyController, 'Secret');
      expect(await notes.changeOpenedNoteLock('1234', locked: true), true);
      expect(storage.notePin, '1234');
      expect(storage.notes.single.isLocked, true);
      expect(storage.notes.single.body, 'Secret');
      notes.setOpenedNote(null);
      notes.titleController.text = 'Another';
      expect(await notes.changeOpenedNoteLock('5678', locked: true), false);
      expect(storage.notes, hasLength(1));
      expect(await notes.changeOpenedNoteLock('1234', locked: true), true);
      expect(storage.notes.every((note) => note.isLocked), true);
    },
  );

  test('locked contents do not match title or body searches', () async {
    storage.notes = [
      makeNote(
        'private',
        title: 'Secret title',
        body: 'Password',
        isLocked: true,
      ),
      makeNote('public', body: 'Public'),
    ];
    await notes.getNotesFromLocalStorage();
    expect(notes.visibleNotes, hasLength(2));
    for (final query in ['secret', 'password']) {
      notes.searchController.text = query;
      expect(notes.visibleNotes, isEmpty);
    }
    notes.searchController.clear();
    expect(notes.visibleNotes, hasLength(2));
  });

  test(
    'opening, editing, removing locks and deleting require the note PIN',
    () async {
      storage.notePin = '1234';
      final original = makeNote('private', isLocked: true);
      storage.notes = [original];
      await notes.getNotesFromLocalStorage();
      notes.setOpenedNote(original);
      notes.titleController.text = 'Changed';
      expect(await notes.saveNote(), false);
      expect(await notes.unlockOpenedNote('0000'), false);
      expect(await notes.changeOpenedNoteLock('0000', locked: false), false);
      expect(await notes.deleteNote(original.id), false);
      expect(await notes.deleteNote(original.id, pin: '0000'), false);
      expect(storage.notes.single, same(original));
      expect(await notes.unlockOpenedNote('1234'), true);
      expect(await notes.saveNote(), true);
      expect(storage.notes.single.isLocked, true);
      expect(await notes.changeOpenedNoteLock('1234', locked: false), true);
      expect(storage.notes.single.isLocked, false);
      expect(storage.notes.single.title, 'Changed');
      expect(await notes.deleteNote(original.id), true);
    },
  );

  test(
    'failed lock, unlock and delete writes preserve saved protection',
    () async {
      storage.notePin = '1234';
      final original = makeNote('original');
      storage.notes = [original];
      await notes.getNotesFromLocalStorage();
      notes.setOpenedNote(original);
      storage.failWrites = true;
      expect(await notes.changeOpenedNoteLock('1234', locked: true), false);
      expect(notes.openedNote, same(original));
      storage.failWrites = false;
      expect(await notes.changeOpenedNoteLock('1234', locked: true), true);
      final locked = storage.notes.single;
      storage.failWrites = true;
      expect(await notes.changeOpenedNoteLock('1234', locked: false), false);
      expect(await notes.deleteNote(locked.id, pin: '1234'), false);
      expect(storage.notes.single, same(locked));
      expect(notes.allNotes.single.isLocked, true);
    },
  );

  test(
    'backgrounding revokes access and stale verification cannot unlock',
    () async {
      storage.notePin = '1234';
      notes.setOpenedNote(makeNote('private', isLocked: true));
      expect(await notes.unlockOpenedNote('1234'), true);
      notes.handleLifecycle(AppLifecycleState.hidden);
      notes.handleLifecycle(AppLifecycleState.resumed);
      notes.titleController.text = 'Draft';
      expect(await notes.saveNote(), false);
      storage.noteVerification = Completer<bool>();
      final pending = notes.unlockOpenedNote('1234');
      notes.handleLifecycle(AppLifecycleState.paused);
      notes.handleLifecycle(AppLifecycleState.resumed);
      storage.noteVerification!.complete(true);
      expect(await pending, false);
      expect(await notes.saveNote(), false);
      storage.noteVerification = null;
      expect(await notes.unlockOpenedNote('1234'), true);
    },
  );

  test(
    'five bad attempts throttle all note operations for thirty seconds',
    () async {
      storage.notePin = '1234';
      notes.setOpenedNote(makeNote('private', isLocked: true));
      for (var attempt = 0; attempt < 5; attempt++) {
        expect(await notes.unlockOpenedNote('0000'), false);
      }
      expect(notes.noteLockError, contains('30 seconds'));
      expect(await notes.unlockOpenedNote('1234'), false);
      expect(await notes.changeOpenedNoteLock('1234', locked: false), false);
      now = now.add(const Duration(seconds: 31));
      expect(await notes.unlockOpenedNote('1234'), true);
    },
  );

  test(
    'App Lock can be disabled without removing the shared note PIN',
    () async {
      storage.notePin = '1234';
      storage.savedPin = '5678';
      storage.appLock = true;
      await storage.saveAppLockChoice(false);
      expect(await notes.unlockOpenedNote('1234'), true);
      expect(storage.notePin, '1234');
    },
  );
}
