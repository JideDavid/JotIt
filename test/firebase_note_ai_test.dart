import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/services/gemini_anchors.dart';
import 'package:jot_it/features/notes/services/note_ai_service.dart';

Map<String, dynamic> proposal(
  List<Map<String, dynamic>> edits, {
  List<String> reviewed = const ['p0'],
}) => {
  'title': '',
  'summary': 'Model claim',
  'design': 'Consistent sections',
  'warnings': <String>[],
  'reviewedParagraphs': reviewed,
  'edits': edits,
};

void main() {
  test(
    'Create normalizes an empty-canvas replacement into editable content',
    () async {
      for (final scope in ['whole', 'new']) {
        final service = NoteAiService(
          token: () async => 'signed-in',
          firebaseGenerate: (_) async => jsonEncode(
            proposal([
              {'kind': 'paragraph', 'paragraphId': 'p0', 'role': 'title'},
              {
                'kind': 'replace',
                'paragraphId': 'p0',
                'blocks': [
                  {'type': 'heading', 'text': 'Content calendar', 'level': 1},
                  {
                    'type': 'paragraph',
                    'text': 'Plan educational videos for your audience.',
                  },
                  {'type': 'checklist', 'text': 'Choose weekly topics'},
                ],
              },
            ]),
          ),
        );
        addTearDown(service.dispose);
        final plan = await service.generate(
          mode: 'Create',
          prompt: 'Create a calendar',
          text: '',
          scope: scope,
        );
        expect(plan.edits.last['kind'], 'insert');
        expect(plan.summary, contains('New content was added'));
        final doc = Document.fromDelta(
          plan.propose(
            Delta()..insert('\n'),
            start: 0,
            length: 0,
            mode: 'Create',
          ),
        );
        addTearDown(doc.close);
        expect(
          doc.toPlainText(),
          contains('Content calendar\nPlan educational videos'),
        );
        final checklistAt = doc.toPlainText().indexOf('Choose weekly topics');
        expect(
          doc.collectStyle(checklistAt, 20).attributes['list']?.value,
          'unchecked',
        );
      }
    },
  );
  test(
    'zero-length replacements remain invalid outside empty Create canvases',
    () {
      for (final entry in [
        ('Format', '', 'whole', 'p0'),
        ('Refine', '', 'whole', 'p0'),
        ('Create', '', 'append', 'p0'),
        ('Create', '', 'selection', 'p0'),
        ('Create', 'Existing\n', 'whole', 'p1'),
      ]) {
        expect(
          () => GeminiAnchors.resolve(
            proposal([
              {
                'kind': 'replace',
                'paragraphId': entry.$4,
                'blocks': [
                  {'type': 'paragraph', 'text': 'New text'},
                ],
              },
            ], reviewed: entry.$2.isEmpty ? ['p0'] : ['p0', 'p1']),
            text: entry.$2,
            mode: entry.$1,
            scope: entry.$3,
            prompt: 'Create',
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('heading typography can accompany its matching semantic role', () {
    final plan = GeminiAnchors.resolve(
      proposal([
        {'kind': 'paragraph', 'paragraphId': 'p0', 'role': 'section'},
        {
          'kind': 'style',
          'paragraphId': 'p0',
          'quote': 'Study tools',
          'styleId': 'amber-heading',
        },
      ]),
      text: 'Study tools',
      mode: 'Format',
      scope: 'whole',
      prompt: 'Colorful',
    );
    final doc = Document.fromDelta(
      plan.propose(
        Delta()..insert('Study tools\n'),
        start: 0,
        length: 11,
        mode: 'Format',
      ),
    );
    addTearDown(doc.close);
    expect(doc.toPlainText(), 'Study tools\n');
    expect(doc.collectStyle(11, 1).attributes['header']?.value, 2);
    expect(doc.collectStyle(0, 11).attributes['color']?.value, '#a66c10');
  });
  test(
    'heading presets cannot enlarge phrases or conflict with paragraph roles',
    () {
      for (final role in ['section', 'title']) {
        expect(
          () => GeminiAnchors.resolve(
            proposal([
              {'kind': 'paragraph', 'paragraphId': 'p0', 'role': role},
              {
                'kind': 'style',
                'paragraphId': 'p0',
                'quote': role == 'section' ? 'Study' : 'Study tools',
                'styleId': 'amber-heading',
              },
            ]),
            text: 'Study tools',
            mode: 'Format',
            scope: 'whole',
            prompt: 'Colorful',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'reason',
              contains('matching paragraph role'),
            ),
          ),
        );
      }
    },
  );
  test('correction receives the precise validation reason', () async {
    var calls = 0;
    final service = NoteAiService(
      token: () async => 'signed-in',
      firebaseGenerate: (input) async {
        calls++;
        if (calls == 2) {
          expect(
            input['validationFeedback'],
            contains('matching paragraph role'),
          );
          return jsonEncode(
            proposal([
              {'kind': 'paragraph', 'paragraphId': 'p0', 'role': 'section'},
            ]),
          );
        }
        return jsonEncode(
          proposal([
            {'kind': 'style', 'paragraphId': 'p0', 'styleId': 'amber-heading'},
          ]),
        );
      },
    );
    addTearDown(service.dispose);
    final plan = await service.generate(
      mode: 'Format',
      prompt: 'Colorful',
      text: 'Study tools',
    );
    expect(calls, 2);
    expect(plan.edits.single['role'], 'section');
  });
  test(
    'four-color proposal is corrected once before previewing, within the same scope',
    () async {
      var attempts = 0;
      final service = NoteAiService(
        token: () async => 'signed-in',
        firebaseGenerate: (input) async {
          attempts++;
          expect(input['text'], 'One\nTwo\nThree\nFour');
          if (attempts == 2) {
            expect(
              input['validationFeedback'],
              contains('three accent colors'),
            );
          }
          final styles = [
            'mint-marker',
            'amber-brush',
            'violet-marker',
            if (attempts == 1) 'lemon-marker',
          ];
          return jsonEncode(
            proposal(
              [
                for (var i = 0; i < styles.length; i++)
                  {'kind': 'style', 'paragraphId': 'p$i', 'styleId': styles[i]},
              ],
              reviewed: ['p0', 'p1', 'p2', 'p3'],
            ),
          );
        },
      );
      addTearDown(service.dispose);
      final plan = await service.generate(
        mode: 'Format',
        prompt: 'Make it more colorful',
        text: 'One\nTwo\nThree\nFour',
      );
      expect(attempts, 2);
      expect(plan.edits.length, 3);
    },
  );
  test(
    'a repeatedly invalid proposal stops after one correction attempt',
    () async {
      var attempts = 0;
      final service = NoteAiService(
        token: () async => 'signed-in',
        firebaseGenerate: (_) async {
          attempts++;
          return jsonEncode(proposal([], reviewed: []));
        },
      );
      addTearDown(service.dispose);
      await expectLater(
        service.generate(mode: 'Format', prompt: 'Format', text: 'Original'),
        throwsFormatException,
      );
      expect(attempts, 2);
    },
  );
  test(
    'Firebase path sends scoped context without a key and compiles a native heading',
    () async {
      final service = NoteAiService(
        token: () async => 'signed-in',
        firebaseGenerate: (input) async {
          expect(input['text'], 'My note');
          expect(input['paragraphs'].single['paragraphId'], 'p0');
          expect(input['paragraphs'].single.containsKey('start'), false);
          expect(input.containsKey('apiKey'), false);
          expect(input.containsKey('token'), false);
          expect(input['catalog'].length, 17);
          expect(input['styles'].first['attributes'], isA<Map>());
          return jsonEncode(
            proposal([
              {'kind': 'paragraph', 'paragraphId': 'p0', 'role': 'section'},
            ]),
          );
        },
      );
      addTearDown(service.dispose);
      expect(service.configured, true);
      final plan = await service.generate(
        mode: 'Format',
        prompt: 'Structure this',
        text: 'My note',
      );
      expect(plan.anchored, true);
      expect(plan.summary, contains('wording is preserved'));
      final doc = Document.fromDelta(
        plan.propose(
          Delta()..insert('My note\n'),
          start: 0,
          length: 7,
          mode: 'Format',
        ),
      );
      addTearDown(doc.close);
      expect(doc.collectStyle(7, 1).attributes['header']?.value, 2);
    },
  );
  test('direct Firebase generation still requires sign-in', () async {
    var called = false;
    final service = NoteAiService(
      token: () async => null,
      firebaseGenerate: (_) async {
        called = true;
        return '{}';
      },
    );
    addTearDown(service.dispose);
    await expectLater(
      service.generate(mode: 'Create', prompt: 'Write', text: ''),
      throwsFormatException,
    );
    expect(called, false);
  });
  test(
    'unknown, ambiguous, partial-word and incomplete anchors are rejected',
    () {
      for (final raw in [
        proposal([
          {
            'kind': 'style',
            'paragraphId': 'p9',
            'quote': 'word',
            'styleId': 'strong',
          },
        ]),
        proposal([
          {
            'kind': 'style',
            'paragraphId': 'p0',
            'quote': 'word',
            'styleId': 'strong',
          },
        ]),
        proposal([
          {
            'kind': 'style',
            'paragraphId': 'p0',
            'quote': 'wor',
            'styleId': 'strong',
          },
        ]),
        proposal([], reviewed: []),
      ]) {
        expect(
          () => GeminiAnchors.resolve(
            raw,
            text: 'word word',
            mode: 'Format',
            scope: 'whole',
            prompt: 'Format',
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('UTF-16 offsets resolve correctly after emoji', () {
    final plan = GeminiAnchors.resolve(
      proposal([
        {
          'kind': 'style',
          'paragraphId': 'p0',
          'quote': 'words',
          'styleId': 'strong',
        },
      ]),
      text: '😀 words',
      mode: 'Format',
      scope: 'whole',
      prompt: 'Bold',
    );
    expect(plan.edits.single['start'], 3);
    expect(plan.edits.single['length'], 5);
  });
  test('Format cannot rewrite, append cannot change existing text', () {
    for (final mode in ['Format', 'Refine']) {
      expect(
        () => GeminiAnchors.resolve(
          proposal([
            {
              'kind': 'replace',
              'paragraphId': 'p0',
              'blocks': [
                {'type': 'paragraph', 'text': 'Changed'},
              ],
            },
          ]),
          text: 'Original',
          mode: mode,
          scope: mode == 'Format' ? 'whole' : 'append',
          prompt: 'Change',
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'mid-paragraph sticker insertion and empty sticker labels are rejected',
    () {
      for (final edit in [
        {
          'kind': 'insert',
          'paragraphId': 'p0',
          'quote': 'words',
          'placement': 'after',
          'blocks': <Map<String, dynamic>>[],
        },
        {
          'kind': 'insert',
          'paragraphId': 'p0',
          'placement': 'after',
          'blocks': [
            {'type': 'sticker', 'text': '', 'formatId': 'ticket'},
          ],
        },
      ]) {
        expect(
          () => GeminiAnchors.resolve(
            proposal([edit]),
            text: 'words',
            mode: 'Format',
            scope: 'whole',
            prompt: 'Decorate',
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'Firebase errors use actionable messages without leaking raw SDK data',
    () async {
      for (final error in [
        QuotaExceeded('private data'),
        ServiceApiNotEnabled('private-project'),
        FirebaseAIException('App Check rejected private-token'),
      ]) {
        final service = NoteAiService(
          token: () async => 'signed-in',
          firebaseGenerate: (_) async => throw error,
        );
        addTearDown(service.dispose);
        await expectLater(
          service.generate(mode: 'Create', prompt: 'Write', text: ''),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'sanitized',
              isNot(contains('private')),
            ),
          ),
        );
      }
    },
  );
}
