import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note_ai_appearance.dart';
import 'package:jot_it/features/notes/model/note_ai_context.dart';
import 'package:jot_it/features/notes/model/note_ai_plan.dart';
import 'package:jot_it/features/notes/model/note_sticker.dart';
import 'package:jot_it/features/notes/services/note_document_edits.dart';
import 'package:jot_it/features/notes/services/note_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NoteAiPlan anchored(List<Map<String, dynamic>> edits) => NoteAiPlan.fromJson({
  'anchored': true,
  'summary': 'Formatted without changing wording',
  'title': '',
  'design': 'Consistent sections and amber accents',
  'warnings': ['Check ambiguous source titles.'],
  'changes': ['${edits.length} changes'],
  'edits': [
    for (final e in edits)
      {
        'start': 0,
        'length': 0,
        'styleId': '',
        'color': '',
        'blocks': const [],
        ...e,
      },
  ],
});
void main() {
  test('new client rejects an old offset-based backend response', () async {
    final service = NoteAiService(
      endpoint: 'https://ai.example.test/v1/assist',
      token: () async => 'test',
      client: MockClient((r) async {
        final input = jsonDecode(r.body) as Map;
        expect(input['version'], 2);
        expect(input['styles'].first['attributes'], isA<Map>());
        expect(input['structure'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'summary': 'Old plan',
            'edits': [
              {
                'kind': 'style',
                'start': 0,
                'length': 4,
                'styleId': 'strong',
                'blocks': [],
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    expect(
      () => service.generate(
        mode: 'Format',
        prompt: 'Make readable',
        text: 'Text',
        structure: NoteAiContext.describe(Delta()..insert('Text\n'), 0, 4),
      ),
      throwsFormatException,
    );
  });
  test('Refine cannot accidentally drop an existing link', () {
    final d = Delta()
      ..insert('Visit ')
      ..insert('this guide', {'link': 'https://example.test/guide'})
      ..insert(' today\n');
    expect(
      () => anchored([
        {
          'kind': 'replace',
          'start': 0,
          'length': 21,
          'blocks': [
            {'type': 'paragraph', 'text': 'Read the guide'},
          ],
        },
      ]).propose(d, start: 0, length: 21, mode: 'Refine'),
      throwsFormatException,
    );
  });
  const dark = NoteAiAppearance(
    background: Color(0xff17191a),
    foreground: Color(0xfff3f0e8),
  );
  test(
    'paragraph roles fix a giant introduction without leaking a heading into body text',
    () {
      final original = Delta()
        ..insert('Ordinary introduction', {'size': '26'})
        ..insert('\n', {'header': 1})
        ..insert('1. Tools\nResources\n');
      final p = anchored([
        {'kind': 'paragraph', 'start': 0, 'length': 21, 'role': 'body'},
        {'kind': 'paragraph', 'start': 22, 'length': 8, 'role': 'section'},
        {'kind': 'style', 'start': 31, 'length': 9, 'styleId': 'strong'},
      ]);
      final result = Document.fromDelta(
        p.propose(
          original,
          start: 0,
          length: 40,
          mode: 'Format',
          appearance: dark,
        ),
      );
      addTearDown(result.close);
      expect(
        result.toPlainText(),
        'Ordinary introduction\n1. Tools\nResources\n',
      );
      expect(result.collectStyle(0, 21).attributes['size']?.value, '18');
      final ops = result.toDelta().toJson();
      expect(
        ops.where((o) => (o['attributes'] as Map?)?['header'] == 1),
        isEmpty,
      );
      expect(
        ops.where((o) => (o['attributes'] as Map?)?['header'] == 2).length,
        1,
      );
      expect(result.collectStyle(31, 9).attributes['bold']?.value, true);
    },
  );
  test(
    'inline emphasis preserves an existing checklist and cannot split a word',
    () {
      final original = Delta()
        ..insert('Review your progress')
        ..insert('\n', {'list': 'unchecked'});
      final p = anchored([
        {'kind': 'style', 'start': 0, 'length': 6, 'styleId': 'strong'},
      ]);
      final doc = Document.fromDelta(
        p.propose(
          original,
          start: 0,
          length: 20,
          mode: 'Format',
          appearance: dark,
        ),
      );
      addTearDown(doc.close);
      expect(doc.toDelta().toJson().last['attributes'], {'list': 'unchecked'});
      expect(
        () => anchored([
          {'kind': 'style', 'start': 1, 'length': 3, 'styleId': 'strong'},
        ]).propose(original, start: 0, length: 20, mode: 'Format'),
        throwsFormatException,
      );
      expect(
        () => anchored([
          {
            'kind': 'insert',
            'start': 12,
            'blocks': [
              {'type': 'doodle', 'formatId': 'star', 'text': ''},
            ],
          },
        ]).propose(original, start: 0, length: 20, mode: 'Format'),
        throwsFormatException,
      );
    },
  );
  test(
    'theme contrast repairs dark accents and uses readable highlight text pairs',
    () {
      final corrected = dark.readable({'color': '#1E40AF'});
      final ink = Color(
        int.parse(
          'ff${(corrected['color'] as String).substring(1)}',
          radix: 16,
        ),
      );
      expect(
        NoteAiAppearance.contrast(ink, dark.background),
        greaterThanOrEqualTo(4.5),
      );
      final highlight = dark.readable({
        'background': '#ff9800',
        'color': '#ffffff',
      });
      expect(highlight['color'], '#000000');
      final p = anchored([
        {
          'kind': 'style',
          'start': 0,
          'length': 5,
          'styleId': 'amber-brush',
          'color': '#FFFFFF',
        },
      ]);
      final doc = Document.fromDelta(
        p.propose(
          Delta()..insert('Words\n'),
          start: 0,
          length: 5,
          mode: 'Format',
          appearance: dark,
        ),
      );
      addTearDown(doc.close);
      expect(doc.collectStyle(0, 5).attributes['color']?.value, '#30240e');
    },
  );
  test(
    'body cleanup runs before focused highlighting and repairs inherited contrast',
    () {
      final original = Delta()
        ..insert('Keep these important words readable', {
          'size': '26',
          'background': '#ff9800',
          'color': '#ffffff',
          'bold': true,
        })
        ..insert('\n', {'header': 1});
      final p = anchored([
        {
          'kind': 'paragraph',
          'start': 0,
          'length': 35,
          'role': 'body',
          'reset': true,
        },
        {'kind': 'style', 'start': 11, 'length': 9, 'styleId': 'amber-brush'},
      ]);
      final doc = Document.fromDelta(
        p.propose(
          original,
          start: 0,
          length: 35,
          mode: 'Format',
          appearance: dark,
        ),
      );
      addTearDown(doc.close);
      expect(doc.collectStyle(0, 4).attributes['background'], isNull);
      expect(
        doc.collectStyle(11, 9).attributes['background']?.value,
        '#ffb52e',
      );
      expect(doc.collectStyle(0, 4).attributes['size']?.value, '18');
      final kept =
          anchored([
            {'kind': 'paragraph', 'start': 0, 'length': 35, 'role': 'body'},
          ]).propose(
            original,
            start: 0,
            length: 35,
            mode: 'Format',
            appearance: dark,
          );
      final keptDoc = Document.fromDelta(kept);
      addTearDown(keptDoc.close);
      expect(keptDoc.collectStyle(0, 4).attributes['color']?.value, '#000000');
    },
  );
  test(
    'scoped context preserves formatting but omits all attachment payloads',
    () {
      final sticker = NoteSticker(id: 'private-id', formatId: 'star');
      final original = Delta()
        ..insert('Before\n')
        ..insert('Colored', {'background': '#ff9800', 'size': '24'})
        ..insert({NoteSticker.embedType: sticker.encode()})
        ..insert({'jotit-media': 'private-media-id'})
        ..insert('\n', {'header': 2})
        ..insert('After\n');
      final context = NoteAiContext.describe(original, 7, 9);
      final json = jsonEncode(context);
      expect(context.length, 1);
      expect(context.single['line'], {'header': 2});
      expect(json, contains('background'));
      expect(json, contains('star'));
      expect(json, contains('\uFFFC'));
      expect(json, isNot(contains('private-id')));
      expect(json, isNot(contains('private-media-id')));
      expect(json, isNot(contains('Before')));
      expect(json, isNot(contains('After')));
    },
  );
  test(
    'complete-line roles create native lists and remain one undoable transaction',
    () {
      final c = QuillController.basic();
      addTearDown(c.dispose);
      c.replaceText(
        0,
        0,
        'Read\nWrite\n',
        const TextSelection.collapsed(offset: 0),
      );
      final original = c.document.toDelta();
      final p = anchored([
        {'kind': 'paragraph', 'start': 0, 'length': 4, 'role': 'checklist'},
        {'kind': 'paragraph', 'start': 5, 'length': 5, 'role': 'bullet'},
      ]);
      final proposed = p.propose(
        original,
        start: 0,
        length: c.document.length - 1,
        mode: 'Format',
        appearance: dark,
      );
      NoteDocumentEdits.compose(c, original.diff(proposed), 0);
      expect(
        c.document
            .toDelta()
            .toJson()
            .where((o) => (o['attributes'] as Map?)?['list'] != null)
            .length,
        2,
      );
      c.undo();
      expect(c.document.toDelta(), original);
      c.redo();
      expect(c.document.toDelta(), proposed);
    },
  );
  test(
    'change report distinguishes formatting from wording and content warnings',
    () {
      final p = anchored([
        {'kind': 'style', 'start': 0, 'length': 4, 'styleId': 'strong'},
      ]);
      expect(p.design, isNotEmpty);
      expect(p.warnings.single, contains('ambiguous'));
      expect(p.changes.single, '1 changes');
      expect(
        () => NoteAiPlan.fromJson({
          'anchored': true,
          'edits': [],
          'warnings': [42],
        }),
        throwsFormatException,
      );
    },
  );
  test('live semantic fixture covers all fourteen sections when present', () {
    final file = File('test/gemini_semantic_plan.fixture.json');
    if (!file.existsSync()) return;
    final fixture = jsonDecode(file.readAsStringSync()) as Map;
    final original = Delta()..insert('${fixture['text']}\n');
    final p = NoteAiPlan.fromJson(fixture['plan']);
    final doc = Document.fromDelta(
      p.propose(
        original,
        start: 0,
        length: (fixture['text'] as String).length,
        mode: 'Format',
        appearance: dark,
      ),
    );
    addTearDown(doc.close);
    expect(
      doc
          .toPlainText()
          .replaceAll('\uFFFC', '')
          .replaceAll(RegExp(r'\n+'), '\n')
          .trim(),
      (fixture['text'] as String).replaceAll(RegExp(r'\n+'), '\n').trim(),
    );
    expect(
      doc
          .toDelta()
          .toJson()
          .where((o) => (o['attributes'] as Map?)?['header'] == 2)
          .length,
      14,
    );
  });
}
