import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/services/note_sync_merge.dart';

Note sample(String id, String body, {bool locked = false}) => Note(
  id: id,
  title: id,
  body: body,
  timestamp: DateTime.utc(2026),
  color: 0,
  isLocked: locked,
  richText: jsonEncode([
    {'insert': '$body\n'},
  ]),
  paper: '{"pattern":"grid"}',
  media: '[{"synthetic":"attachment"}]',
);

void main() {
  test(
    'backup round trips all note fields and excludes device credentials',
    () {
      final note = sample('a', 'Words', locked: true);
      final bytes = NoteBackupCodec.encode([note]);
      expect(
        NoteBackupCodec.signature(NoteBackupCodec.decode(bytes).single),
        NoteBackupCodec.signature(note),
      );
      expect(utf8.decode(bytes), isNot(contains('note_lock_pin')));
      expect(() => NoteBackupCodec.encode([note, note]), throwsFormatException);
      expect(
        () => NoteBackupCodec.decode(utf8.encode('{"schema":2,"notes":[]}')),
        throwsFormatException,
      );
    },
  );

  test(
    'offline edits on separate notes merge without using timestamps',
    () async {
      final a = sample('a', 'before'), b = sample('b', 'before');
      final merged = await NoteSyncMerge.reconcile(
        base: [a, b],
        local: [sample('a', 'local'), b],
        remote: [a, sample('b', 'remote')],
      );
      expect(merged.notes.map((n) => n.body), ['local', 'remote']);
      expect(merged.conflicts, 0);
    },
  );

  test(
    'conflicting edits preserve both versions and the stronger lock',
    () async {
      final before = sample('a', 'before');
      final local = sample('a', 'local', locked: true),
          remote = sample('a', 'remote');
      final merged = await NoteSyncMerge.reconcile(
        base: [before],
        local: [local],
        remote: [remote],
      );
      expect(merged.notes.map((n) => n.body).toSet(), {'local', 'remote'});
      expect(merged.notes.every((n) => n.isLocked), true);
      final retry = await NoteSyncMerge.reconcile(
        base: [before],
        local: [local],
        remote: [remote],
      );
      expect(
        NoteBackupCodec.encode(retry.notes),
        NoteBackupCodec.encode(merged.notes),
      );
    },
  );

  test(
    'acknowledged deletions propagate; edit/delete keeps a conflict copy',
    () async {
      final before = sample('a', 'before');
      expect(
        (await NoteSyncMerge.reconcile(
          base: [before],
          local: [before],
          remote: [],
        )).notes,
        isEmpty,
      );
      final result = await NoteSyncMerge.reconcile(
        base: [before],
        local: [sample('a', 'edit')],
        remote: [],
      );
      expect(result.notes.single.body, 'edit');
      expect(result.notes.single.id, startsWith('conflict-'));
      expect(
        (await NoteSyncMerge.reconcile(
          base: [before],
          local: [],
          remote: [sample('a', 'edit')],
        )).notes.single.body,
        'edit',
      );
    },
  );
}
