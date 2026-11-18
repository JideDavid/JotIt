import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../model/note.dart';
import '../model/note_card_color.dart';

/// Only note data crosses the backup boundary. PINs, auth, recovery capabilities
/// and device preferences deliberately have no representation in this codec.
class NoteBackupCodec {
  static const maxBytes = 64 * 1024 * 1024;
  static const maxNotes = 2000;

  static Map<String, dynamic> noteJson(Note note) => {
    'id': note.id,
    'title': note.title,
    'body': note.body,
    'timestamp': note.timestamp.toUtc().toIso8601String(),
    'color': note.color,
    'isLocked': note.isLocked,
    'richText': note.richText,
    'paper': note.paper,
    'media': note.media,
  };

  static String signature(Note? note) =>
      note == null ? 'deleted' : jsonEncode(noteJson(note));

  static List<int> encode(List<Note> notes) {
    final sorted = List<Note>.of(notes)..sort((a, b) => a.id.compareTo(b.id));
    if (sorted.length > maxNotes ||
        sorted.map((n) => n.id).toSet().length != sorted.length) {
      throw const FormatException(
        'The backup has too many or duplicate notes.',
      );
    }
    final bytes = utf8.encode(
      jsonEncode({'schema': 1, 'notes': sorted.map(noteJson).toList()}),
    );
    if (bytes.length > maxBytes) {
      throw const FormatException(
        'This library exceeds the 64 MB backup limit.',
      );
    }
    // Apply identical validation to local exports and remote imports.
    decode(bytes);
    return bytes;
  }

  static List<Note> decode(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('This backup exceeds the supported size.');
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map ||
        data['schema'] != 1 ||
        data['notes'] is! List ||
        (data['notes'] as List).length > maxNotes) {
      throw const FormatException('Unsupported note backup.');
    }
    final ids = <String>{};
    final notes = <Note>[];
    for (final raw in data['notes']) {
      if (raw is! Map ||
          raw['id'] is! String ||
          (raw['id'] as String).isEmpty ||
          (raw['id'] as String).length > 160 ||
          !ids.add(raw['id']) ||
          raw['title'] is! String ||
          raw['body'] is! String ||
          raw['isLocked'] is! bool ||
          raw['color'] is! int ||
          !NoteCardColor.isValid(raw['color']) ||
          raw['timestamp'] is! String ||
          DateTime.tryParse(raw['timestamp']) == null ||
          [
            'richText',
            'paper',
            'media',
          ].any((k) => raw[k] != null && raw[k] is! String)) {
        throw const FormatException('The backup contains an invalid note.');
      }
      notes.add(
        Note(
          id: raw['id'],
          title: raw['title'],
          body: raw['body'],
          timestamp: DateTime.parse(raw['timestamp']),
          color: raw['color'],
          isLocked: raw['isLocked'],
          richText: raw['richText'],
          paper: raw['paper'],
          media: raw['media'],
        ),
      );
    }
    return notes;
  }
}

class NoteSyncMerge {
  NoteSyncMerge(this.notes, this.conflicts);
  final List<Note> notes;
  final int conflicts;

  /// Three-way merge uses the last acknowledged snapshot, never device clocks.
  /// Conflicting edits become deterministic copies; delete/edit keeps the edit.
  static Future<NoteSyncMerge> reconcile({
    required List<Note> base,
    required List<Note> local,
    required List<Note> remote,
  }) async {
    Map<String, Note> index(List<Note> notes) => {
      for (final n in notes) n.id: n,
    };
    final b = index(base), l = index(local), r = index(remote);
    final result = <String, Note>{};
    final ids = {...b.keys, ...l.keys, ...r.keys}.toList()..sort();
    var conflicts = 0;
    for (final id in ids) {
      final before = b[id], here = l[id], there = r[id];
      final bs = NoteBackupCodec.signature(before);
      final ls = NoteBackupCodec.signature(here);
      final rs = NoteBackupCodec.signature(there);
      if (ls == rs || rs == bs) {
        if (here != null) result[id] = here;
      } else if (ls == bs) {
        if (there != null) result[id] = there;
      } else {
        conflicts++;
        final locked = (here?.isLocked ?? false) || (there?.isLocked ?? false);
        if (there != null) result[id] = _copy(there, id, locked: locked);
        if (here != null) {
          // Preserve a remotely deleted original as a new note, rather than
          // silently resurrecting an ID that another device removed.
          final hash = await Sha256().hash(utf8.encode('$id\n$ls'));
          final suffix = hash.bytes
              .map((v) => v.toRadixString(16).padLeft(2, '0'))
              .join();
          final copyId = 'conflict-$suffix';
          result[copyId] = _copy(
            here,
            copyId,
            title: '${here.title} (conflict copy)',
            locked: locked,
          );
        }
      }
    }
    // A previously generated conflict can also arrive as a normal remote note.
    // Its deterministic ID makes retries and repeated merges idempotent.
    final notes = result.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    NoteBackupCodec.encode(notes);
    return NoteSyncMerge(notes, conflicts);
  }

  static Note _copy(
    Note note,
    String id, {
    String? title,
    required bool locked,
  }) => Note(
    id: id,
    title: title ?? note.title,
    body: note.body,
    timestamp: note.timestamp,
    color: note.color,
    isLocked: locked,
    richText: note.richText,
    paper: note.paper,
    media: note.media,
  );
}
