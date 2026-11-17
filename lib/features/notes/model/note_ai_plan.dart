import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../../../core/utils/random_id_generator.dart';
import 'note_sticker.dart';
import 'note_text_style.dart';
import 'note_ai_appearance.dart';

/// Gemini proposes bounded operations in UTF-16 coordinates of the chosen
/// scope. Only known native styles and catalog formats can enter the document.
class NoteAiPlan {
  NoteAiPlan._(
    this.summary,
    this.title,
    this.edits,
    this.design,
    this.warnings,
    this.changes,
    this.anchored,
  );
  final String summary, title;
  final List<Map<String, dynamic>> edits;
  final String design;
  final List<String> warnings, changes;
  final bool anchored;
  factory NoteAiPlan.fromJson(dynamic json) {
    if (json is! Map ||
        json['edits'] is! List ||
        (json['edits'] as List).length >
            (json['anchored'] == true ? 200 : 40)) {
      throw const FormatException(
        'AI returned an invalid edit plan. Try a simpler prompt.',
      );
    }
    String text(dynamic value, int max) =>
        value is String && value.length <= max
        ? value
        : throw const FormatException('AI returned text that is too long.');
    final edits = <Map<String, dynamic>>[];
    for (final raw in json['edits']) {
      if (raw is! Map ||
          ![
            'style',
            'insert',
            'replace',
            'remove-sticker',
            'paragraph',
          ].contains(raw['kind']) ||
          raw['start'] is! int ||
          raw['length'] is! int ||
          raw['start'] < 0 ||
          raw['length'] < 0) {
        throw const FormatException('AI returned an invalid edit range.');
      }
      final e = Map<String, dynamic>.from(raw);
      if (e['kind'] == 'paragraph' &&
          ![
            'body',
            'title',
            'section',
            'subheading',
            'bullet',
            'numbered',
            'checklist',
            'quote',
          ].contains(e['role'])) {
        throw const FormatException('AI returned an invalid paragraph role.');
      }
      if (e['styleId'] != null && e['styleId'] is! String) {
        throw const FormatException('AI returned an invalid style.');
      }
      if (e['kind'] == 'style' &&
          NoteTextStyles.find(e['styleId'] as String? ?? '') == null) {
        throw const FormatException('AI selected an unavailable text style.');
      }
      if (e['color'] != null &&
          e['color'] != '' &&
          NoteTextStyle.colorValue(e['color']) == null) {
        throw const FormatException('AI returned an invalid color.');
      }
      final blocks = e['blocks'] ?? const [];
      if (blocks is! List || blocks.length > 100) {
        throw const FormatException('AI returned too many note blocks.');
      }
      for (final block in blocks) {
        if (block is! Map ||
            ![
              'paragraph',
              'heading',
              'checklist',
              'bullet',
              'numbered',
              'quote',
              'sticker',
              'doodle',
            ].contains(block['type'])) {
          throw const FormatException(
            'AI returned an unsupported note element.',
          );
        }
        text(block['text'] ?? '', 10000);
        text(block['body'] ?? '', 500);
        if (block['text'] is String &&
            (block['text'] as String).contains('\uFFFC')) {
          throw const FormatException(
            'AI returned an invalid object reference.',
          );
        }
        if (block['styleId'] != null &&
            (block['styleId'] is! String ||
                block['styleId'] != '' &&
                    NoteTextStyles.find(block['styleId']) == null)) {
          throw const FormatException('AI selected an unavailable style.');
        }
        if (block['color'] != null &&
            block['color'] != '' &&
            NoteTextStyle.colorValue(block['color']) == null) {
          throw const FormatException('AI returned an invalid color.');
        }
        if (['sticker', 'doodle'].contains(block['type'])) {
          final format = block['formatId'] is String
              ? StickerCatalog.find(block['formatId'])
              : null;
          if (format == null ||
              (block['type'] == 'doodle') != format.isDoodle) {
            throw const FormatException(
              'AI selected an unavailable sticker format.',
            );
          }
          text(block['text'] ?? '', 100);
        }
      }
      e['blocks'] = blocks;
      edits.add(e);
    }
    if (edits.isEmpty && json['anchored'] != true) {
      throw const FormatException(
        'AI did not propose any changes. Try another prompt.',
      );
    }
    return NoteAiPlan._(
      text(json['summary'] ?? 'Review the proposed changes.', 400),
      text(json['title'] ?? '', 100),
      edits,
      text(json['design'] ?? '', 400),
      _strings(json['warnings'], 8, 250),
      _strings(json['changes'], 8, 100),
      json['anchored'] == true,
    );
  }

  static List<String> _strings(dynamic value, int max, int chars) {
    if (value == null) return const [];
    if (value is! List ||
        value.length > max ||
        value.any((v) => v is! String || v.length > chars)) {
      throw const FormatException('AI returned an invalid change summary.');
    }
    return value.cast<String>();
  }

  Delta propose(
    Delta original, {
    required int start,
    required int length,
    required String mode,
    NoteAiAppearance? appearance,
  }) {
    final originalDoc = Document.fromDelta(original);
    try {
      if (start < 0 || length < 0 || start + length > originalDoc.length - 1) {
        throw const FormatException(
          'The selected text has changed. Please select it again.',
        );
      }
      final text = originalDoc.toPlainText(),
          scope = text.substring(start, start + length);
      final sorted =
          edits.where((e) => e['kind'] != 'paragraph').indexed.toList()
            ..sort((a, b) {
              final order = (a.$2['start'] as int).compareTo(
                b.$2['start'] as int,
              );
              return order == 0 ? a.$1.compareTo(b.$1) : order;
            });
      var cursor = 0;
      final change = Delta()..retain(start);
      var generated = 0;
      final lineStyles = <int, Map<String, dynamic>>{};
      final paragraphStyles = Delta();
      var paragraphCursor = 0;
      for (final e
          in (edits.where((e) => e['kind'] == 'paragraph').toList()..sort(
            (a, b) => (a['start'] as int).compareTo(b['start'] as int),
          ))) {
        final at = e['start'] as int,
            n = e['length'] as int,
            global = start + at;
        final end = text.indexOf('\n', global);
        if (at < 0 ||
            at + n > length ||
            end != global + n ||
            (global > 0 && text[global - 1] != '\n') ||
            lineStyles.containsKey(end)) {
          throw const FormatException(
            'Paragraph formatting must target a complete line.',
          );
        }
        final role = e['role'];
        lineStyles[end] = {
          'header': null,
          'list': null,
          'blockquote': null,
          'align': null,
          if (role == 'title') 'header': 1,
          if (role == 'section') 'header': 2,
          if (role == 'subheading') 'header': 3,
          if (role == 'bullet') 'list': 'bullet',
          if (role == 'numbered') 'list': 'ordered',
          if (role == 'checklist')
            'list':
                originalDoc.collectStyle(end, 1).attributes['list']?.value ==
                    'checked'
                ? 'checked'
                : 'unchecked',
          if (role == 'quote') 'blockquote': true,
        };
        paragraphStyles.retain(global - paragraphCursor);
        if (n > 0) {
          paragraphStyles.retain(n, {
            'size': role == 'body' ? '18' : null,
            if (e['reset'] == true)
              for (final key in [
                'bold',
                'italic',
                'underline',
                'strike',
                'font',
                'color',
                'background',
              ])
                key: null,
            if (e['color'] is String && (e['color'] as String).isNotEmpty)
              'color': e['color'],
          });
        }
        paragraphCursor = global + n;
      }
      bool splitsEmoji(int offset) =>
          offset > 0 &&
          offset < text.length &&
          text.codeUnitAt(offset) >= 0xdc00 &&
          text.codeUnitAt(offset) <= 0xdfff &&
          text.codeUnitAt(offset - 1) >= 0xd800 &&
          text.codeUnitAt(offset - 1) <= 0xdbff;
      for (final indexed in sorted) {
        final edit = indexed.$2;
        final at = edit['start'] as int,
            n = edit['length'] as int,
            kind = edit['kind'];
        if (at < cursor ||
            at + n > scope.length ||
            (kind == 'insert' && n != 0)) {
          throw const FormatException(
            'AI returned overlapping or out-of-scope changes.',
          );
        }
        if (splitsEmoji(start + at) || splitsEmoji(start + at + n)) {
          throw const FormatException(
            'AI split a text character. Try the request again.',
          );
        }
        if (kind == 'replace' && mode == 'Format') {
          throw const FormatException(
            'Formatting cannot rewrite your words. Use Refine to change the wording.',
          );
        }
        final selected = scope.substring(at, at + n);
        bool splitsWord(int offset) =>
            offset > 0 &&
            offset < text.length &&
            RegExp(
              r'[\p{L}\p{M}\p{N}_]$',
              unicode: true,
            ).hasMatch(text.substring(0, offset)) &&
            RegExp(
              r'^[\p{L}\p{M}\p{N}_]',
              unicode: true,
            ).hasMatch(text.substring(offset));
        if (anchored &&
            (splitsWord(start + at) || splitsWord(start + at + n))) {
          throw const FormatException(
            'An AI edit would split a word. Your note is unchanged.',
          );
        }
        if (anchored &&
            kind == 'insert' &&
            start + at > 0 &&
            start + at < text.length - 1 &&
            text[start + at - 1] != '\n' &&
            text[start + at] != '\n') {
          throw const FormatException(
            'Place new elements at a paragraph boundary.',
          );
        }
        if (kind == 'replace' && selected.contains('\uFFFC')) {
          throw const FormatException(
            'Select text without attachments or stickers to rewrite it.',
          );
        }
        if (kind == 'replace' &&
            originalDoc
                .toDelta()
                .slice(start + at, start + at + n)
                .toJson()
                .any((op) => (op['attributes'] as Map?)?['link'] != null)) {
          throw const FormatException(
            'Rewrite text around existing links, or select a smaller phrase. Links are preserved.',
          );
        }
        if (kind == 'remove-sticker') {
          final matches = originalDoc
              .toDelta()
              .slice(start + at, start + at + n)
              .toJson();
          if (n != 1 ||
              matches.length != 1 ||
              NoteSticker.fromInsert(matches.single['insert']) == null) {
            throw const FormatException('AI cannot remove this attachment.');
          }
        }
        change.retain(at - cursor);
        if (kind == 'style') {
          final preset = NoteTextStyles.find(edit['styleId'])!;
          var attrs = <String, dynamic>{
            if (edit['reset'] == true || !anchored)
              for (final key in [
                'bold',
                'italic',
                'underline',
                'strike',
                'font',
                'size',
                'color',
                'background',
                'header',
                'blockquote',
                'align',
                'list',
              ])
                key: null,
            ...preset.attributes,
          };
          if (edit['color'] is String &&
              (edit['color'] as String).isNotEmpty &&
              (!anchored || preset.attributes['background'] == null)) {
            attrs['color'] = edit['color'];
          }
          if (anchored) {
            attrs.removeWhere((k, v) => Attribute.blockKeys.contains(k));
            attrs = appearance?.readable(attrs) ?? attrs;
          }
          final inline = <String, dynamic>{
            for (final e in attrs.entries)
              if (Attribute.inlineKeys.contains(e.key)) e.key: e.value,
          };
          final block = <String, dynamic>{
            for (final e in attrs.entries)
              if (Attribute.blockKeys.contains(e.key)) e.key: e.value,
          };
          var run = 0;
          for (var i = 0; i < selected.length; i++) {
            if (selected[i] == '\n') {
              if (run > 0) change.retain(run, inline);
              change.retain(1, block);
              run = 0;
            } else {
              run++;
            }
          }
          if (run > 0) change.retain(run, inline);
          // Native block formatting belongs to the line's newline, including
          // when the selected words stop before that newline.
          if (n > 0 && !anchored) {
            var lineEnd = text.indexOf('\n', start + at);
            while (lineEnd >= 0) {
              lineStyles[lineEnd] = block;
              if (lineEnd >= start + at + n - 1) break;
              lineEnd = text.indexOf('\n', lineEnd + 1);
            }
          }
        } else {
          if (kind != 'remove-sticker') {
            final blocks = edit['blocks'] as List;
            final inlineReplacement =
                kind == 'replace' &&
                blocks.length == 1 &&
                blocks.first['type'] == 'paragraph' &&
                !(blocks.first['text'] as String).contains('\n') &&
                !selected.contains('\n');
            if (!inlineReplacement &&
                blocks.isNotEmpty &&
                !['sticker', 'doodle'].contains(blocks.first['type']) &&
                start + at > 0 &&
                text[start + at - 1] != '\n') {
              change.insert('\n');
            }
            for (final raw in blocks) {
              final b = Map<String, dynamic>.from(raw as Map), type = b['type'];
              var attrs = <String, dynamic>{
                if (inlineReplacement)
                  ...?originalDoc.collectStyle(start + at, n).toJson(),
                ...?NoteTextStyles.find(b['styleId'] ?? '')?.attributes,
              };
              if (b['color'] is String && (b['color'] as String).isNotEmpty) {
                attrs['color'] = b['color'];
              }
              if (anchored) attrs = appearance?.readable(attrs) ?? attrs;
              if (type == 'sticker' || type == 'doodle') {
                final format = StickerCatalog.find(b['formatId'])!;
                final color =
                    NoteTextStyle.colorValue(b['color'])?.toARGB32() ??
                    0xffe9af35;
                final sticker = NoteSticker(
                  id: RandomId().generate(),
                  formatId: format.id,
                  text: b['text'] ?? format.text,
                  body: b['body'] ?? format.body,
                  color: color,
                  width: format.width,
                );
                change.insert({NoteSticker.embedType: sticker.encode()});
                generated++;
              } else {
                final inline = {
                  for (final e in attrs.entries)
                    if (Attribute.inlineKeys.contains(e.key)) e.key: e.value,
                };
                final block = <String, dynamic>{
                  for (final e in attrs.entries)
                    if (Attribute.blockKeys.contains(e.key)) e.key: e.value,
                };
                if (type == 'heading') {
                  block['header'] = (b['level'] is int ? b['level'] as int : 2)
                      .clamp(1, 3);
                }
                if (type == 'quote') block['blockquote'] = true;
                if (type == 'checklist') {
                  block['list'] = b['checked'] == true
                      ? 'checked'
                      : 'unchecked';
                }
                if (type == 'bullet') block['list'] = 'bullet';
                if (type == 'numbered') block['list'] = 'ordered';
                final lines = (b['text'] as String? ?? '').split('\n');
                for (final line in lines) {
                  if (line.isNotEmpty) change.insert(line, inline);
                  if (!inlineReplacement) change.insert('\n', block);
                }
              }
            }
          }
          if (n > 0) change.delete(n);
        }
        cursor = at + n;
      }
      if (generated > 40) {
        throw const FormatException('Add fewer stickers in one request.');
      }
      // Paragraph cleanup precedes phrase emphasis, so a body reset can safely
      // coexist with a short highlight without erasing that new highlight.
      var result =
          (paragraphStyles.isEmpty
                  ? original
                  : original.compose(paragraphStyles))
              .compose(change);
      if (lineStyles.isNotEmpty) {
        final blocks = Delta();
        var offset = 0;
        for (final entry
            in lineStyles.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))) {
          final position = change.transformPosition(entry.key, force: false);
          blocks.retain(position - offset);
          blocks.retain(1, entry.value);
          offset = position + 1;
        }
        result = result.compose(blocks);
      }
      if (anchored && appearance != null) {
        final from = change.transformPosition(start, force: false),
            to = change.transformPosition(start + length, force: true);
        final contrastPatch = Delta();
        var offset = 0, patched = 0;
        for (final op in result.toList()) {
          final n = op.length ?? 0, attrs = op.attributes;
          final lo = offset < from ? from : offset,
              hi = offset + n > to ? to : offset + n;
          if (op.data is String &&
              attrs != null &&
              hi > lo &&
              (attrs['background'] != null || attrs['color'] != null)) {
            final readable = appearance.readable(attrs);
            if (readable['color'] != attrs['color']) {
              contrastPatch.retain(lo - patched);
              contrastPatch.retain(hi - lo, {'color': readable['color']});
              patched = hi;
            }
          }
          offset += n;
        }
        if (contrastPatch.isNotEmpty) result = result.compose(contrastPatch);
      }
      final checked = Document.fromDelta(result);
      final tooLong = checked.length > 100000;
      checked.close();
      if (tooLong) {
        throw const FormatException('The proposed note is too long.');
      }
      return result;
    } finally {
      originalDoc.close();
    }
  }
}
