import 'package:flutter_quill/quill_delta.dart';
import 'note_sticker.dart';

/// Describe only the chosen scope. Never serialize media bytes or embed IDs.
class NoteAiContext {
  static List<Map<String, dynamic>> describe(
    Delta document,
    int start,
    int length,
  ) {
    final paragraphs = <Map<String, dynamic>>[];
    var runs = <Map<String, dynamic>>[];
    void finish(Map<String, dynamic> line) {
      paragraphs.add({
        'paragraphId': 'p${paragraphs.length}',
        'runs': runs,
        'line': line,
      });
      runs = [];
    }

    for (final op in document.slice(start, start + length).toJson()) {
      final attrs = Map<String, dynamic>.from(op['attributes'] as Map? ?? {}),
          insert = op['insert'];
      if (insert is String) {
        final parts = insert.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            runs.add({
              'text': parts[i],
              'attributes': {
                for (final e in attrs.entries)
                  if (![
                    'header',
                    'list',
                    'blockquote',
                    'align',
                    'indent',
                  ].contains(e.key))
                    e.key: e.value,
              },
            });
          }
          if (i < parts.length - 1) {
            finish({
              for (final e in attrs.entries)
                if ([
                  'header',
                  'list',
                  'blockquote',
                  'align',
                  'indent',
                ].contains(e.key))
                  e.key: e.value,
            });
          }
        }
      } else {
        final sticker = NoteSticker.fromInsert(insert);
        runs.add({
          'text': '\uFFFC',
          'attributes': {},
          if (sticker != null) 'formatId': sticker.formatId,
        });
      }
    }
    // The last line's newline can be outside the selected text scope.
    final tail = document.slice(start + length, start + length + 1).toJson();
    final line = tail.isNotEmpty && tail.first['insert'] == '\n'
        ? Map<String, dynamic>.from(tail.first['attributes'] as Map? ?? {})
        : <String, dynamic>{};
    finish(line);
    return paragraphs;
  }
}
