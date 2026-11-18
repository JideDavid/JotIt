import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/services/note_ai_request.dart';
import 'package:jot_it/features/notes/services/note_ai_service.dart';

String valid() => jsonEncode({
  'title': '',
  'design': 'Keep the original',
  'warnings': [],
  'reviewedParagraphs': ['p0'],
  'edits': [],
});

void main() {
  test(
    'provider timeout suppresses late invalid results and automatic correction',
    () async {
      final response = Completer<String>();
      var calls = 0;
      final service = NoteAiService(
        token: () async => 'session',
        requestTimeout: const Duration(milliseconds: 20),
        firebaseGenerate: (_) {
          calls++;
          return response.future;
        },
      );
      addTearDown(service.dispose);
      await expectLater(
        service.generate(mode: 'Create', prompt: 'Guide', text: ''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('took too long'),
          ),
        ),
      );
      response.complete('{}');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );
  test(
    'sign-in failures are actionable and do not reveal SDK details',
    () async {
      final service = NoteAiService(
        token: () async => throw StateError('private-token'),
        firebaseGenerate: (_) async => valid(),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.generate(mode: 'Format', prompt: 'Format', text: 'Original'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('AI session'), isNot(contains('private-token'))),
          ),
        ),
      );
    },
  );
  test('progress reports validation and one correction in order', () async {
    final stages = <NoteAiStage>[];
    var calls = 0;
    final service = NoteAiService(
      token: () async => 'session',
      firebaseGenerate: (_) async {
        return ++calls == 1 ? '{}' : valid();
      },
    );
    addTearDown(service.dispose);
    await service.generate(
      mode: 'Format',
      prompt: 'Format',
      text: 'Original',
      onStage: stages.add,
    );
    expect(stages, [
      NoteAiStage.checkingSession,
      NoteAiStage.generating,
      NoteAiStage.checkingProposal,
      NoteAiStage.correcting,
      NoteAiStage.checkingProposal,
    ]);
    expect(calls, 2);
  });
  test('cancelling before sign-in finishes sends no content', () async {
    final auth = Completer<String?>(), cancellation = NoteAiCancellation();
    var calls = 0;
    final service = NoteAiService(
      token: () => auth.future,
      firebaseGenerate: (_) async {
        calls++;
        return valid();
      },
    );
    addTearDown(service.dispose);
    final pending = service.generate(
      mode: 'Format',
      prompt: 'Format',
      text: 'Original',
      cancellation: cancellation,
    );
    final assertion = expectLater(pending, throwsA(isA<NoteAiCancelled>()));
    cancellation.cancel();
    await assertion;
    auth.complete('session');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
  });
  test(
    'a late invalid response after stop cannot trigger a correction',
    () async {
      final response = Completer<String>(), sent = Completer<void>();
      final cancellation = NoteAiCancellation();
      var calls = 0;
      final service = NoteAiService(
        token: () async => 'session',
        firebaseGenerate: (_) {
          calls++;
          sent.complete();
          return response.future;
        },
      );
      addTearDown(service.dispose);
      final pending = service.generate(
        mode: 'Create',
        prompt: 'Guide',
        text: '',
        cancellation: cancellation,
      );
      final assertion = expectLater(pending, throwsA(isA<NoteAiCancelled>()));
      await sent.future;
      cancellation.cancel();
      await assertion;
      response.complete('{}');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );
  test(
    'deadline also bounds stalled sign-in and rejects its late result',
    () async {
      final auth = Completer<String?>();
      var calls = 0;
      final service = NoteAiService(
        token: () => auth.future,
        requestTimeout: const Duration(milliseconds: 20),
        firebaseGenerate: (_) async {
          calls++;
          return valid();
        },
      );
      addTearDown(service.dispose);
      await expectLater(
        service.generate(mode: 'Format', prompt: 'Format', text: 'Original'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('took too long'),
          ),
        ),
      );
      auth.complete('session');
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
    },
  );
}
