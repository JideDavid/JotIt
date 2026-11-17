import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/model/note_attachment.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/services/note_media_controller.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'support/fakes.dart';

class _Recorder implements NoteRecorderBackend {
  bool permitted = true;
  int starts = 0;
  int stops = 0;
  Completer<bool>? permission;
  final chunks = StreamController<Uint8List>();
  @override
  Future<bool> hasPermission() async => permission?.future ?? permitted;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    return chunks.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {
    await chunks.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  NoteAttachment audio(String id) => NoteAttachment(
    id: id,
    name: 'Voice note.wav',
    mimeType: 'audio/wav',
    bytes: NoteMediaController.wavFromPcm(Uint8List.fromList([1, 2, 3, 4])),
  );

  test('media bytes round-trip with JSON and are immutable copies', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final original = NoteAttachment(
      id: 'one',
      name: r'C:\secret\image.png',
      mimeType: 'image/png',
      bytes: bytes,
    );
    bytes[0] = 9;
    expect(original.name, 'image.png');
    expect(original.bytes.first, 1);
    expect(() => original.bytes[0] = 2, throwsUnsupportedError);
    final encoded = NoteAttachment.encodeAll([original]);
    expect(NoteAttachment.decodeAll(encoded).single.bytes, [1, 2, 3]);
    expect(NoteAttachment.kindsIn(encoded), [NoteAttachmentKind.image]);
    final note = makeNote('one', media: encoded);
    expect(Note.fromJson(note.toJson()).media, encoded);
    expect(Note.fromJson({'id': 'old'}).media, isNull);
    for (final malformed in ['{broken', '{}', '[{}]']) {
      expect(NoteAttachment.decodeAll(malformed), isEmpty);
    }
  });

  group('inline media drafts', () {
    late MemoryStorage storage;
    late NoteViewModel notes;
    setUp(() {
      storage = MemoryStorage();
      notes = NoteViewModel(notesRepo: NotesRepo(localStorageService: storage));
    });
    tearDown(() => notes.dispose());

    test(
      'moving media up and down preserves text, bytes, save and undo',
      () async {
        setBodyText(notes.bodyController, 'First\nSecond\nThird');
        notes.bodyController.formatText(6, 6, Attribute.bold);
        notes.attachMedia(
          audio('move'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        final before = notes.bodyController.document.toDelta().toJson();
        expect(notes.moveAttachment('move', 15), true);
        expect(
          notes.bodyController.document.toPlainText(),
          'First\nSecond\n\uFFFC\nThird\n',
        );
        final moved = notes.bodyController.document.toDelta().toJson();
        notes.bodyController.undo();
        expect(notes.bodyController.document.toDelta().toJson(), before);
        notes.bodyController.redo();
        expect(notes.bodyController.document.toDelta().toJson(), moved);
        expect(notes.attachments.single.bytes, audio('move').bytes);
        expect(await notes.saveNote(), true);
        notes.setOpenedNote(storage.notes.single);
        expect(notes.bodyController.document.toDelta().toJson(), moved);
        expect(notes.moveAttachment('move', 0), true);
        expect(notes.bodyController.document.toDelta().toJson(), before);
      },
    );

    test(
      'moving into styled text splits the paragraph without losing styles',
      () {
        setBodyText(notes.bodyController, 'BeforeAfter');
        notes.bodyController.formatText(0, 11, Attribute.bold);
        notes.bodyController.formatText(0, 11, Attribute.h2);
        notes.attachMedia(
          audio('move'),
          selection: const TextSelection.collapsed(offset: 0),
        );
        expect(notes.moveAttachment('move', 8), true);
        expect(
          notes.bodyController.document.toPlainText(),
          'Before\n\uFFFC\nAfter\n',
        );
        final delta = notes.bodyController.document.toDelta().toJson();
        expect(
          delta.where((op) => op['attributes']?['header'] == 2),
          hasLength(2),
        );
        expect(
          delta
              .where((op) => op['attributes']?['bold'] == true)
              .map((op) => op['insert'])
              .join(),
          'BeforeAfter',
        );
      },
    );

    test('moves can reorder media and no-op drops leave history unchanged', () {
      setBodyText(notes.bodyController, 'Text');
      notes.attachMedia(
        audio('one'),
        selection: const TextSelection.collapsed(offset: 0),
      );
      notes.attachMedia(audio('two'));
      expect(notes.moveAttachment('two', 0), true);
      final ids = notes.bodyController.document
          .toDelta()
          .toJson()
          .map((op) => NoteAttachment.embeddedId(op['insert']))
          .whereType<String>();
      expect(ids, ['two', 'one']);
      final before = notes.bodyController.document.toDelta().toJson();
      expect(notes.moveAttachment('two', 0), false);
      expect(notes.moveAttachment('two', 1), false);
      expect(notes.moveAttachment('two', 2), false);
      expect(notes.moveAttachment('missing', 4), false);
      expect(notes.bodyController.document.toDelta().toJson(), before);
    });

    test(
      'moves are rejected while saving, locked or in the background',
      () async {
        notes.titleController.text = 'Private';
        notes.attachMedia(audio('move'));
        storage.writeBarrier = Completer<void>();
        final saving = notes.saveNote();
        expect(notes.moveAttachment('move', 2), false);
        storage.writeBarrier!.complete();
        await saving;
        await notes.changeOpenedNoteLock('1234', locked: true);
        notes.setOpenedNote(storage.notes.single);
        expect(notes.canMoveAttachments, false);
        expect(notes.moveAttachment('move', 2), false);
        await notes.unlockOpenedNote('1234');
        expect(notes.canMoveAttachments, true);
        notes.handleLifecycle(AppLifecycleState.paused);
        expect(notes.canMoveAttachments, false);
      },
    );

    test(
      'insertion between text preserves formatting and saved bytes on reopen',
      () async {
        setBodyText(notes.bodyController, 'Before\nAfter');
        notes.bodyController.formatText(0, 6, Attribute.bold);
        expect(
          notes.attachMedia(
            audio('voice'),
            selection: const TextSelection.collapsed(offset: 7),
          ),
          true,
        );
        expect(notes.bodyText, contains('Before'));
        expect(notes.bodyText, contains('After'));
        expect(notes.bodyText, isNot(contains('\uFFFC')));
        expect(
          notes.bodyController.document.toPlainText(),
          'Before\n\uFFFC\nAfter\n',
        );
        expect(notes.attachments.single.id, 'voice');
        expect(await notes.saveNote(), true);
        final saved = storage.notes.single;
        expect(saved.richText, contains('bold'));
        expect(saved.richText, contains(NoteAttachment.embedType));
        expect(
          NoteAttachment.decodeAll(saved.media).single.bytes,
          audio('voice').bytes,
        );
        notes.setOpenedNote(saved);
        expect(notes.attachments.single.id, 'voice');
        expect(notes.hasUnsavedChanges, false);
      },
    );

    test(
      'consecutive attachments occupy their own paragraphs without consuming text',
      () {
        setBodyText(notes.bodyController, 'Keep every character');
        notes.bodyController.updateSelection(
          const TextSelection.collapsed(offset: 0),
          ChangeSource.local,
        );
        notes.attachMedia(audio('first'));
        notes.attachMedia(audio('second'));
        expect(
          notes.bodyController.document.toPlainText(),
          '\uFFFC\n\uFFFC\nKeep every character\n',
        );
        expect(notes.bodyController.selection.extentOffset, 4);
        notes.bodyController.undo();
        expect(
          notes.bodyController.document.toPlainText(),
          '\uFFFC\nKeep every character\n',
        );
        expect(notes.attachments.single.id, 'first');
        notes.bodyController.undo();
        expect(
          notes.bodyController.document.toPlainText(),
          'Keep every character\n',
        );
      },
    );

    test(
      'insertion within styled text preserves both halves and paragraph attributes',
      () async {
        setBodyText(notes.bodyController, 'BeforeAfter');
        notes.bodyController.formatText(0, 11, Attribute.bold);
        notes.bodyController.formatText(0, 11, Attribute.h2);
        final original = notes.bodyController.document.toDelta().toJson();
        notes.attachMedia(
          audio('middle'),
          selection: const TextSelection.collapsed(offset: 6),
        );
        expect(
          notes.bodyController.document.toPlainText(),
          'Before\n\uFFFC\nAfter\n',
        );
        final delta = notes.bodyController.document.toDelta().toJson();
        expect(
          delta.where((operation) => operation['attributes']?['header'] == 2),
          hasLength(2),
        );
        expect(
          delta
              .where((operation) => operation['attributes']?['bold'] == true)
              .map((operation) => operation['insert'])
              .join(),
          'BeforeAfter',
        );
        notes.bodyController.undo();
        expect(notes.bodyController.document.toDelta().toJson(), original);
        expect(notes.attachments, isEmpty);
      },
    );

    test(
      'attachment-only note saves and failed saves retain bytes and draft',
      () async {
        notes.attachMedia(audio('one'));
        expect(notes.hasUnsavedChanges, true);
        storage.failWrites = true;
        expect(await notes.saveNote(), false);
        expect(notes.attachments.single.bytes, audio('one').bytes);
        storage.failWrites = false;
        expect(await notes.saveNote(), true);
        expect(notes.hasUnsavedChanges, false);
        notes.removeAttachmentAt(0);
        expect(notes.hasUnsavedChanges, true);
        notes.bodyController.undo();
        expect(notes.attachments.single.id, 'one');
      },
    );

    test(
      'media inserted during a pending save remains an unsaved draft',
      () async {
        notes.titleController.text = 'Draft';
        notes.attachMedia(audio('one'));
        storage.writeBarrier = Completer<void>();
        final saving = notes.saveNote();
        expect(notes.attachMedia(audio('two')), false);
        storage.writeBarrier!.complete();
        expect(await saving, true);
        notes.attachMedia(audio('two'));
        expect(notes.hasUnsavedChanges, true);
        expect(
          NoteAttachment.decodeAll(storage.notes.single.media),
          hasLength(1),
        );
        expect(await notes.saveNote(), true);
        expect(
          NoteAttachment.decodeAll(storage.notes.single.media),
          hasLength(2),
        );
      },
    );

    test(
      'removal prunes saved bytes, undo restores the in-session attachment',
      () async {
        notes.titleController.text = 'Keep';
        notes.attachMedia(audio('one'));
        await notes.saveNote();
        notes.removeAttachmentAt(0);
        expect(notes.attachments, isEmpty);
        expect(await notes.saveNote(), true);
        expect(storage.notes.single.media, isNull);
        notes.bodyController.undo();
        expect(notes.attachments.single.bytes, audio('one').bytes);
        expect(notes.hasUnsavedChanges, true);
      },
    );

    test(
      'locked note cannot be changed before authentication or after backgrounding',
      () async {
        notes.titleController.text = 'Private';
        notes.attachMedia(audio('one'));
        expect(await notes.changeOpenedNoteLock('1234', locked: true), true);
        final saved = storage.notes.single;
        notes.setOpenedNote(saved);
        expect(notes.attachMedia(audio('two')), false);
        notes.removeAttachmentAt(0);
        expect(notes.attachments, hasLength(1));
        expect(await notes.unlockOpenedNote('1234'), true);
        expect(notes.attachMedia(audio('two')), true);
        notes.handleLifecycle(AppLifecycleState.paused);
        expect(notes.attachMedia(audio('three')), false);
        notes.handleLifecycle(AppLifecycleState.resumed);
        expect(await notes.unlockOpenedNote('1234'), true);
        expect(notes.attachments, hasLength(2));
      },
    );

    test(
      'invalid media and duplicate identifiers are rejected without replacing content',
      () {
        notes.attachMedia(audio('one'));
        expect(notes.attachMedia(audio('one')), false);
        expect(
          notes.attachMedia(
            NoteAttachment(
              id: 'big',
              name: 'big.wav',
              mimeType: 'audio/wav',
              bytes: Uint8List(NoteAttachment.maxFileBytes + 1),
            ),
          ),
          false,
        );
        expect(notes.attachments, hasLength(1));
      },
    );

    test(
      'a missing rich-text body cannot orphan valid saved attachments',
      () async {
        final old = makeNote(
          'old-media',
          body: 'Keep my text',
          media: NoteAttachment.encodeAll([audio('one')]),
        );
        storage.notes = [old];
        await notes.getNotesFromLocalStorage();
        notes.setOpenedNote(old);
        expect(notes.attachments.single.id, 'one');
        notes.titleController.text = 'Updated';
        expect(await notes.saveNote(), true);
        expect(
          NoteAttachment.decodeAll(storage.notes.single.media).single.bytes,
          audio('one').bytes,
        );
        expect(storage.notes.single.body, contains('Keep my text'));
      },
    );

    test('malformed existing media is preserved by text-only saves', () async {
      final old = makeNote('broken', media: '{not-readable');
      storage.notes = [old];
      await notes.getNotesFromLocalStorage();
      notes.setOpenedNote(old);
      notes.titleController.text = 'Updated title';
      expect(await notes.saveNote(), true);
      expect(storage.notes.single.media, old.media);
      expect(notes.attachMedia(audio('new')), false);
    });
  });

  test('WAV headers describe mono 16kHz PCM and strip incomplete samples', () {
    final wav = NoteMediaController.wavFromPcm(
      Uint8List.fromList([1, 2, 3, 4, 5]),
    );
    final header = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(40, Endian.little), 4);
    expect(wav.sublist(44), [1, 2, 3, 4]);
  });

  test(
    'recorder stops on privacy lock, retains audio, and never resumes behind a lock',
    () async {
      final backend = _Recorder();
      final media = NoteMediaController(recorder: backend);
      addTearDown(media.dispose);
      await media.startRecording();
      backend.chunks.add(Uint8List.fromList([1, 2, 3, 4]));
      await Future<void>.delayed(Duration.zero);
      media.setPrivacyAllowed(false);
      await media.stopRecording();
      await Future<void>.delayed(Duration.zero);
      expect(media.recordingState, NoteRecordingState.stopped);
      expect(media.hasRecording, true);
      media.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await media.startRecording();
      expect(backend.starts, 1);
      expect(media.recordingNotice, contains('inactive'));
      media.setPrivacyAllowed(true);
      await media.discardRecording();
      expect(media.recordedBytes, isNull);
    },
  );

  testWidgets(
    'denied and late permissions cannot start a recorder behind the privacy gate',
    (tester) async {
      final backend = _Recorder()..permitted = false;
      final media = NoteMediaController(recorder: backend);
      addTearDown(media.dispose);
      await media.startRecording();
      expect(backend.starts, 0);
      expect(media.error, contains('denied'));
      backend.permission = Completer<bool>();
      final starting = media.startRecording();
      await tester.pump();
      media.setPrivacyAllowed(false);
      backend.permission!.complete(true);
      await starting;
      expect(backend.starts, 0);
      expect(media.recordingState, NoteRecordingState.ready);
    },
  );
}
