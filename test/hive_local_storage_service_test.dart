import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:jot_it/core/constants/z_strings.dart';
import 'package:jot_it/core/services/hive_local_storage_service.dart';
import 'package:jot_it/core/services/pin_hasher.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/model/note_paper.dart';
import 'package:jot_it/features/notes/model/note_attachment.dart';
import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<dynamic> authBox;
  late Box<dynamic> noteBox;
  late HiveLocalStorageService storage;

  setUpAll(() {
    Hive.registerAdapter(NoteAdapter());
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jotit-storage-test-');
    Hive.init(directory.path);
    authBox = await Hive.openBox('auth');
    noteBox = await Hive.openBox('notes');
    storage = HiveLocalStorageService(authBox, noteBox);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'deleting notes targets the note box and leaves authentication untouched',
    () async {
      await authBox.put('all', 'auth value');
      await storage.saveNotes([makeNote('one')], 'all');
      await storage.deleteNotes('all');
      expect(storage.getNotes('all'), isEmpty);
      expect(authBox.get('all'), 'auth value');
    },
  );

  test('clearAll clears both boxes', () async {
    await authBox.put('user', 'saved');
    await storage.saveNotes([makeNote('one')], 'all');
    await storage.clearAll();
    expect(authBox.isEmpty, true);
    expect(noteBox.isEmpty, true);
  });
  test(
    'recovery PIN envelopes survive reopen and preserve notes and App Lock',
    () async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('jotit/pin_hash');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => Uint8List(32));
      addTearDown(() {
        debugDefaultTargetPlatformOverride = previous;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final digest = '${List.filled(43, 'A').join()}=';
      await authBox.put('note_lock_pin', {
        'hash': 'pbkdf2-sha256:600000:AAAAAAAAAAAAAAAAAAAAAA==:$digest',
        'recovery': {'enabled': true, 'uid': 'owner'},
        'pendingReset': null,
      });
      await storage.saveNotes([makeNote('protected', isLocked: true)], 'all');
      await storage.saveAppLockPin('1357');
      await storage.saveAppLockChoice(true);
      await authBox.close();
      await noteBox.close();
      authBox = await Hive.openBox('auth');
      noteBox = await Hive.openBox('notes');
      storage = HiveLocalStorageService(authBox, noteBox);
      expect(await storage.verifyNoteLockPin('2468'), true);
      expect(storage.hasNoteLockPin(), true);
      expect(storage.getAppLockChoice(), true);
      expect(storage.getNotes('all').single.isLocked, true);
      expect((authBox.get('note_lock_pin') as Map)['recovery']['uid'], 'owner');
    },
  );

  test(
    'custom colors and favorite preferences survive reopening without changing media or PINs',
    () async {
      await storage.saveNotes([
        makeNote(
          'custom',
          color: 0xff123456,
          richText: '[{"insert":"Text\\n"}]',
          media: 'preserved',
        ),
      ], 'all');
      await storage.saveFavoriteNoteColors([0xff123456, 0xffabcdef]);
      await authBox.put('note_lock_pin', 'unchanged');
      await Hive.close();
      authBox = await Hive.openBox('auth');
      noteBox = await Hive.openBox('notes');
      storage = HiveLocalStorageService(authBox, noteBox);
      expect(storage.getNotes('all').single.color, 0xff123456);
      expect(storage.getNotes('all').single.media, 'preserved');
      expect(storage.getFavoriteNoteColors(), [0xff123456, 0xffabcdef]);
      expect(authBox.get('note_lock_pin'), 'unchanged');
      await expectLater(
        storage.saveFavoriteNoteColors([1]),
        throwsArgumentError,
      );
      await authBox.put('favorite_note_colors', [
        null,
        'bad',
        1,
        0xff123456,
        0xff123456,
      ]);
      expect(storage.getFavoriteNoteColors(), [0xff123456]);
    },
  );

  test(
    'appearance preference persists independently of notes and PINs',
    () async {
      expect(storage.hasExistingData(), false);
      expect(storage.getAppearance(), isNull);
      await storage.saveAppearance('light');
      await storage.saveNotes([makeNote('keep')], 'all');
      await authBox.close();
      authBox = await Hive.openBox('auth');
      storage = HiveLocalStorageService(authBox, noteBox);
      expect(storage.getAppearance(), 'light');
      expect(storage.hasExistingData(), true);
      expect(storage.getNotes('all').single.id, 'keep');
      await expectLater(storage.saveAppearance('invalid'), throwsArgumentError);
      expect(storage.getAppearance(), 'light');
    },
  );

  test(
    'shared note PIN is hashed, survives restart and is independent of App Lock',
    () async {
      expect(storage.hasNoteLockPin(), false);
      await storage.createNoteLockPin('2468');
      expect(storage.hasNoteLockPin(), true);
      expect(authBox.get('note_lock_pin'), startsWith('pbkdf2-sha256:600000:'));
      await storage.saveAppLockChoice(false);
      await authBox.close();
      authBox = await Hive.openBox('auth');
      storage = HiveLocalStorageService(authBox, noteBox);
      expect(await storage.verifyNoteLockPin('2468'), true);
      expect(await storage.verifyNoteLockPin('1234'), false);
      await expectLater(storage.createNoteLockPin('9999'), throwsStateError);
      await expectLater(storage.createNoteLockPin('bad'), throwsArgumentError);
      await storage.clearAll();
      expect(storage.hasNoteLockPin(), false);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('rich-text formatting survives closing and reopening Hive', () async {
    final note = makeNote(
      'rich',
      body: 'Hello',
      richText:
          '[{"insert":"Hello","attributes":{"bold":true}},{"insert":"\\n"}]',
    );
    await storage.saveNotes([note], 'all');
    await noteBox.close();
    noteBox = await Hive.openBox('notes');
    final restored = HiveLocalStorageService(
      authBox,
      noteBox,
    ).getNotes('all').single;
    expect(restored.richText, note.richText);
    expect(restored.body, 'Hello');
  });

  test('paper customization survives closing and reopening Hive', () async {
    const paper = NotePaper(
      pattern: NotePaperPattern.grid,
      tone: NotePaperTone.sage,
    );
    await storage.saveNotes([makeNote('paper', paper: paper.encode())], 'all');
    await noteBox.close();
    noteBox = await Hive.openBox('notes');
    final restored = HiveLocalStorageService(
      authBox,
      noteBox,
    ).getNotes('all').single;
    expect(NotePaper.decode(restored.paper), paper);
  });

  test(
    'inline attachment bytes survive Hive restart with rich text and paper',
    () async {
      final media = NoteAttachment.encodeAll([
        NoteAttachment(
          id: 'attachment',
          name: 'clip.wav',
          mimeType: 'audio/wav',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ]);
      final original = makeNote(
        'media',
        media: media,
        richText: '[{"insert":"Hello\\n"}]',
        paper: const NotePaper(pattern: NotePaperPattern.dots).encode(),
      );
      await storage.saveNotes([original], 'all');
      await noteBox.close();
      noteBox = await Hive.openBox('notes');
      final restored = HiveLocalStorageService(
        authBox,
        noteBox,
      ).getNotes('all').single;
      expect(NoteAttachment.decodeAll(restored.media).single.bytes, [
        1,
        2,
        3,
        4,
      ]);
      expect(restored.richText, original.richText);
      expect(restored.paper, original.paper);
    },
  );

  test('the new adapter reads existing six-field Hive notes', () async {
    Hive.registerAdapter<Note>(_LegacyNoteAdapter(), override: true);
    await storage.saveNotes([makeNote('legacy', body: 'Existing text')], 'all');
    await Hive.close();
    Hive.registerAdapter<Note>(NoteAdapter(), override: true);
    authBox = await Hive.openBox('auth');
    noteBox = await Hive.openBox('notes');
    final restored = HiveLocalStorageService(
      authBox,
      noteBox,
    ).getNotes('all').single;
    expect(restored.id, 'legacy');
    expect(restored.body, 'Existing text');
    expect(restored.richText, isNull);
    expect(NotePaper.decode(restored.paper), const NotePaper());
  });

  test(
    'seven-field rich-text notes retain formatting with plain paper',
    () async {
      Hive.registerAdapter<Note>(
        _LegacyNoteAdapter(includeRichText: true),
        override: true,
      );
      final original = makeNote(
        'rich-legacy',
        body: 'Existing rich text',
        richText:
            '[{"insert":"Existing rich text\\n","attributes":{"bold":true}}]',
      );
      await storage.saveNotes([original], 'all');
      await Hive.close();
      Hive.registerAdapter<Note>(NoteAdapter(), override: true);
      authBox = await Hive.openBox('auth');
      noteBox = await Hive.openBox('notes');
      final restored = HiveLocalStorageService(
        authBox,
        noteBox,
      ).getNotes('all').single;
      expect(restored.richText, original.richText);
      expect(restored.body, original.body);
      expect(NotePaper.decode(restored.paper), const NotePaper());
    },
  );

  test(
    'eight-field paper notes retain text, formatting and paper after media support',
    () async {
      Hive.registerAdapter<Note>(
        _LegacyNoteAdapter(includePaper: true),
        override: true,
      );
      final original = makeNote(
        'paper-legacy',
        body: 'Keep me',
        richText: '[{"insert":"Keep me\\n","attributes":{"bold":true}}]',
        paper: const NotePaper(pattern: NotePaperPattern.ruled).encode(),
      );
      await storage.saveNotes([original], 'all');
      await Hive.close();
      Hive.registerAdapter<Note>(NoteAdapter(), override: true);
      authBox = await Hive.openBox('auth');
      noteBox = await Hive.openBox('notes');
      final reopened = HiveLocalStorageService(authBox, noteBox);
      final restored = reopened.getNotes('all').single;
      expect(restored.media, isNull);
      expect(restored.richText, original.richText);
      expect(restored.paper, original.paper);
      expect(restored.body, original.body);
      await reopened.saveNotes([restored], 'all');
      expect(reopened.getNotes('all').single.paper, original.paper);
    },
  );

  test(
    'reading and resaving notes never reverses them or exposes the stored list',
    () async {
      await storage.saveNotes([makeNote('one'), makeNote('two')], 'all');
      final notes = storage.getNotes('all');
      await storage.saveNotes(notes, 'all');
      expect(storage.getNotes('all').map((note) => note.id), ['one', 'two']);
      notes.clear();
      expect(storage.getNotes('all'), hasLength(2));
      await noteBox.close();
      noteBox = await Hive.openBox('notes');
      final reopened = HiveLocalStorageService(authBox, noteBox);
      expect(reopened.getNotes('all').map((note) => note.id), ['one', 'two']);
    },
  );

  test(
    'new PINs are salted hashes and correct and incorrect PINs are distinguished',
    () async {
      await storage.saveAppLockPin('1234');
      final encoded = authBox.get(ZStrings.appLockPinKey) as String;
      expect(encoded, startsWith('pbkdf2-sha256:600000:'));
      expect(await storage.verifyAppLockPin('1234'), true);
      expect(await storage.verifyAppLockPin('5678'), false);
      await storage.saveAppLockPin('1234');
      expect(authBox.get(ZStrings.appLockPinKey), isNot(encoded));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'legacy PIN migrates only after successful verification',
    () async {
      await authBox.put(ZStrings.appLockPinKey, '4321');
      expect(await storage.verifyAppLockPin('0000'), false);
      expect(authBox.get(ZStrings.appLockPinKey), '4321');
      expect(await storage.verifyAppLockPin('4321'), true);
      expect(
        authBox.get(ZStrings.appLockPinKey),
        startsWith('pbkdf2-sha256:600000:'),
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('missing and malformed PIN records fail closed', () async {
    expect(await storage.verifyAppLockPin(''), false);
    expect(await storage.verifyAppLockPin('1234'), false);
    expect(await PinHasher().verify('1234', 'pbkdf2-sha256:600000:?:?'), false);
    await expectLater(storage.saveAppLockPin('12'), throwsArgumentError);
    await expectLater(storage.saveAppLockChoice(true), throwsStateError);
  });

  test(
    'disabling App Lock clears its PIN and biometric preference together',
    () async {
      await authBox.put(ZStrings.appLockPinKey, '1234');
      await storage.saveAppLockChoice(true);
      await storage.saveBiometricEnabled(true);
      await storage.saveAppLockChoice(false);
      expect(storage.getAppLockChoice(), false);
      expect(storage.getBiometricEnabled(), false);
      expect(await storage.verifyAppLockPin('1234'), false);
    },
  );
}

class _LegacyNoteAdapter extends TypeAdapter<Note> {
  _LegacyNoteAdapter({this.includeRichText = false, this.includePaper = false});
  final bool includeRichText;
  final bool includePaper;

  @override
  final int typeId = 1;

  @override
  Note read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, Note note) {
    writer
      ..writeByte(
        includePaper
            ? 8
            : includeRichText
            ? 7
            : 6,
      )
      ..writeByte(0)
      ..write(note.id)
      ..writeByte(1)
      ..write(note.title)
      ..writeByte(2)
      ..write(note.body)
      ..writeByte(3)
      ..write(note.timestamp)
      ..writeByte(4)
      ..write(note.color)
      ..writeByte(5)
      ..write(note.isLocked);
    if (includeRichText || includePaper) {
      writer
        ..writeByte(6)
        ..write(note.richText);
    }
    if (includePaper) {
      writer
        ..writeByte(7)
        ..write(note.paper);
    }
  }
}
