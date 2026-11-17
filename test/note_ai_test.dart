import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jot_it/features/notes/model/note_ai_plan.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/services/note_ai_service.dart';
import 'package:jot_it/features/notes/services/note_document_edits.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/note_ai_workspace.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';
import 'support/fakes.dart';

Map<String, dynamic> plan(List<Map<String, dynamic>> edits) => {
  'summary': 'Ready to review',
  'title': 'Tutorial plan',
  'edits': edits,
};
Map<String, dynamic> edit(
  String kind,
  int start,
  int length, {
  String style = '',
  List<Map<String, dynamic>> blocks = const [],
}) => {
  'kind': kind,
  'start': start,
  'length': length,
  'styleId': style,
  'color': '',
  'blocks': blocks,
};
Map<String, dynamic> block(
  String type,
  String text, {
  String format = '',
  String color = '',
}) => {
  'type': type,
  'text': text,
  'formatId': format,
  'styleId': '',
  'color': color,
  'level': 2,
  'checked': false,
  'body': '',
};
String plain(Delta d) {
  final doc = Document.fromDelta(d);
  try {
    return doc.toPlainText();
  } finally {
    doc.close();
  }
}

void main() {
  test('a real Gemini response compiles into editable native elements', () {
    final p = NoteAiPlan.fromJson(
      jsonDecode(File('test/gemini_note_plan.fixture.json').readAsStringSync()),
    );
    final doc = Document.fromDelta(
      p.propose(Delta()..insert('\n'), start: 0, length: 0, mode: 'Create'),
    );
    addTearDown(doc.close);
    expect(NoteDocumentEdits.stickers(doc).map((s) => s.sticker.formatId), [
      'pinned-paper',
      'star',
    ]);
    expect(
      doc
          .toDelta()
          .toJson()
          .where((o) => (o['attributes'] as Map?)?['list'] == 'unchecked')
          .length,
      2,
    );
  });
  testWidgets(
    'phone AI review supports follow-ups, original preview and atomic Apply',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage(), connection = TestConnection();
      final auth = AuthViewModel(
        authRepository: TestAuthRepository(storage),
        localBiometricService: TestBiometrics(),
        internetCheckerService: connection,
      );
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(auth.dispose);
      addTearDown(connection.dispose);
      addTearDown(notes.dispose);
      setBodyText(notes.bodyController, 'My words');
      final original = notes.bodyController.document.toDelta();
      var requests = 0;
      final service = NoteAiService(
        endpoint: 'https://ai.example.test/v1/assist',
        token: () async => 'token',
        client: MockClient((r) async {
          requests++;
          return http.Response(
            jsonEncode({
              ...plan([
                edit(
                  'style',
                  0,
                  8,
                  style: requests == 1 ? 'strong' : 'amber-brush',
                ),
                if (requests == 1)
                  edit(
                    'insert',
                    8,
                    0,
                    blocks: [block('doodle', '', format: 'star')],
                  ),
              ]),
              'anchored': true,
              'design': 'Readable body text and short amber emphasis.',
              'changes': ['1 text style'],
              'warnings': ['Review ambiguous resource names.'],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            localizationsDelegates: const [FlutterQuillLocalizations.delegate],
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteAiWorkspace(
                        notes: notes,
                        selection: const TextSelection(
                          baseOffset: 0,
                          extentOffset: 8,
                        ),
                        service: service,
                      ),
                    ),
                  ),
                  child: const Text('Open AI'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open AI'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Make it bold and add a star',
      );
      await tester.tap(find.text('Preview changes'));
      await tester.pumpAndSettle();
      expect(find.text('Proposed'), findsOneWidget);
      expect(notes.bodyController.document.toDelta(), original);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('1 to review'));
      await tester.pumpAndSettle();
      expect(find.text('Content to review'), findsOneWidget);
      expect(find.text('Review ambiguous resource names.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Make it more colorful');
      await tester.tap(find.text('Update preview'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(notes.stickers.single.sticker.formatId, 'star');
      expect(
        notes.bodyController.document
            .collectStyle(0, 8)
            .attributes['background']
            ?.value,
        '#ffb52e',
      );
      notes.bodyController.undo();
      expect(notes.bodyController.document.toDelta(), original);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'preview preserves original, compiles native blocks and undoes atomically',
    () {
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: MemoryStorage()),
      );
      addTearDown(notes.dispose);
      setBodyText(notes.bodyController, 'Original words');
      final original = notes.bodyController.document.toDelta();
      final p = NoteAiPlan.fromJson(
        plan([
          edit('style', 0, 14, style: 'amber-brush'),
          edit(
            'insert',
            14,
            0,
            blocks: [
              block('heading', 'Post your tutorial'),
              block('checklist', 'Upload the video'),
              block(
                'sticker',
                'Remember',
                format: 'pinned-paper',
                color: '#66AA88',
              ),
              block('doodle', '', format: 'star'),
            ],
          ),
        ]),
      );
      final proposed = p.propose(
        original,
        start: 0,
        length: 14,
        mode: 'Format',
      );
      expect(notes.bodyController.document.toDelta(), original);
      final doc = Document.fromDelta(proposed);
      addTearDown(doc.close);
      expect(
        doc.toPlainText(),
        contains('Original words\nPost your tutorial\nUpload the video\n'),
      );
      expect(
        doc.toDelta().toJson().any(
          (o) =>
              o['attributes'] is Map &&
              (o['attributes'] as Map)['list'] == 'unchecked',
        ),
        isTrue,
      );
      expect(NoteDocumentEdits.stickers(doc).length, 2);
      expect(NoteDocumentEdits.stickers(doc).first.sticker.color, 0xff66aa88);
      expect(
        notes.applyAiProposal(
          notes.bodyController.document,
          original,
          proposed,
        ),
        isTrue,
      );
      notes.bodyController.undo();
      expect(notes.bodyController.document.toDelta(), original);
      notes.bodyController.redo();
      expect(notes.bodyController.document.toDelta(), proposed);
    },
  );
  test('scope offsets preserve surrounding text and UTF16 characters', () {
    final original = Delta()..insert('Before 😀 good after\n');
    final p = NoteAiPlan.fromJson(
      plan([
        edit('replace', 3, 4, blocks: [block('paragraph', 'great')]),
      ]),
    );
    expect(
      plain(p.propose(original, start: 7, length: 7, mode: 'Refine')),
      'Before 😀 great after\n',
    );
    final split = NoteAiPlan.fromJson(
      plan([edit('style', 1, 1, style: 'strong')]),
    );
    expect(
      () => split.propose(original, start: 7, length: 7, mode: 'Format'),
      throwsFormatException,
    );
  });
  test('heading styles attach to a selected line even without its newline', () {
    final d = Delta()..insert('Heading\nNext line\n');
    final p = NoteAiPlan.fromJson(
      plan([edit('style', 0, 7, style: 'editorial')]),
    );
    final result = Document.fromDelta(
      p.propose(d, start: 0, length: 7, mode: 'Format'),
    );
    addTearDown(result.close);
    expect(
      result.toDelta().toJson().any(
        (o) => o['insert'] == '\n' && (o['attributes'] as Map?)?['header'] == 1,
      ),
      isTrue,
    );
  });
  test(
    'rejects overlap, rewriting in Format, unsafe assets and unknown formats',
    () {
      final media = Delta()
        ..insert('Text ')
        ..insert({'jot-media': 'media-1'})
        ..insert('\n');
      for (final edits in [
        [
          edit('replace', 0, 6, blocks: [block('paragraph', 'New')]),
        ],
        [edit('remove-sticker', 5, 1)],
        [
          edit('style', 0, 4, style: 'strong'),
          edit('style', 2, 2, style: 'gentle'),
        ],
        [edit('style', 0, 99, style: 'strong')],
      ]) {
        expect(
          () => NoteAiPlan.fromJson(
            plan(edits),
          ).propose(media, start: 0, length: 6, mode: 'Refine'),
          throwsFormatException,
        );
      }
      expect(
        () => NoteAiPlan.fromJson(
          plan([
            edit(
              'insert',
              0,
              0,
              blocks: [block('doodle', '', format: 'not-in-catalog')],
            ),
          ]),
        ),
        throwsFormatException,
      );
      expect(
        () => NoteAiPlan.fromJson(
          plan([
            edit('replace', 0, 4, blocks: [block('paragraph', 'New')]),
          ]),
        ).propose(media, start: 0, length: 6, mode: 'Format'),
        throwsFormatException,
      );
    },
  );
  test('changed, locked and switched documents reject stale proposals', () {
    final notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: MemoryStorage()),
    );
    addTearDown(notes.dispose);
    setBodyText(notes.bodyController, 'Text');
    final document = notes.bodyController.document,
        original = document.toDelta();
    final proposed = Delta()..insert('New\n');
    setBodyText(notes.bodyController, 'Edited');
    expect(notes.applyAiProposal(document, original, proposed), isFalse);
    notes.setOpenedNote(makeNote('locked', isLocked: true));
    expect(notes.applyAiProposal(document, original, proposed), isFalse);
  });
  test(
    'new AI note saves independently and survives reopen without altering current draft',
    () async {
      final storage = MemoryStorage();
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(notes.dispose);
      setBodyText(notes.bodyController, 'Unsaved draft');
      notes.titleController.text = 'Keep me';
      final original = notes.bodyController.document.toDelta();
      final proposed = NoteAiPlan.fromJson(
        plan([
          edit(
            'insert',
            0,
            0,
            blocks: [
              block('checklist', 'Upload video'),
              block('sticker', 'Reminder', format: 'ticket'),
            ],
          ),
        ]),
      ).propose(Delta()..insert('\n'), start: 0, length: 0, mode: 'Create');
      expect(await notes.saveGeneratedNote(proposed, 'Tutorial plan'), isTrue);
      expect(notes.bodyController.document.toDelta(), original);
      expect(notes.titleController.text, 'Keep me');
      expect(notes.openedNote, isNull);
      notes.setOpenedNote(storage.notes.single);
      expect(notes.stickers.single.sticker.formatId, 'ticket');
      expect(notes.bodyText, contains('Upload video'));
    },
  );
  test(
    'Gemini transport sends only scoped text with authenticated backend request',
    () async {
      final service = NoteAiService(
        endpoint: 'https://ai.example.test/v1/assist',
        token: () async => 'firebase-token',
        client: MockClient((request) async {
          expect(request.url.host, 'ai.example.test');
          expect(request.headers['Authorization'], 'Bearer firebase-token');
          final body = jsonDecode(request.body) as Map;
          expect(body['text'], 'Chosen words');
          expect(body.containsKey('apiKey'), isFalse);
          expect(body['catalog'].length, 17);
          return http.Response(
            jsonEncode(plan([edit('style', 0, 12, style: 'strong')])),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      expect(
        (await service.generate(
          mode: 'Format',
          prompt: 'Make it stronger',
          text: 'Chosen words',
        )).edits.length,
        1,
      );
    },
  );
  test(
    'quota, malformed responses and missing connection are actionable failures',
    () async {
      for (final response in [
        http.Response('{}', 429),
        http.Response('not JSON', 200),
        http.Response('{}', 401),
      ]) {
        final service = NoteAiService(
          endpoint: 'https://ai.example.test/v1/assist',
          token: () async => 'token',
          client: MockClient((_) async => response),
        );
        addTearDown(service.dispose);
        expect(
          () => service.generate(
            mode: 'Create',
            prompt: 'Write a note',
            text: '',
          ),
          throwsFormatException,
        );
      }
      final service = NoteAiService(endpoint: '', token: () async => null);
      addTearDown(service.dispose);
      expect(
        () =>
            service.generate(mode: 'Create', prompt: 'Write a note', text: ''),
        throwsFormatException,
      );
    },
  );
}
