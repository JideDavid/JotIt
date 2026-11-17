import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/note_pin_prompt.dart';
import 'support/fakes.dart';

void main() {
  testWidgets(
    'note unlock has no button and auto-verifies on the fourth digit',
    (tester) async {
      final storage = MemoryStorage()..notePin = '2468';
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(notes.dispose);
      var calls = 0;
      var succeeded = false;
      var verification = Completer<bool>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notes,
          child: MaterialApp(
            theme: LSTAppTheme.lightTheme,
            home: Scaffold(
              body: NotePinPrompt(
                fullPage: true,
                title: 'Unlock note',
                submitLabel: 'Unlock note',
                onSubmit: (pin) {
                  calls++;
                  expect(pin, '2468');
                  return verification.future;
                },
                onSuccess: () => succeeded = true,
              ),
            ),
          ),
        ),
      );
      final field = find.widgetWithText(TextField, 'Note PIN');
      await tester.enterText(field, '246');
      await tester.pump();
      expect(calls, 0);
      expect(find.widgetWithText(TextButton, 'Unlock note'), findsNothing);
      await tester.enterText(field, '2468');
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(field).enabled, false);
      verification.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.widgetWithText(TextButton, 'Unlock note'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      verification = Completer<bool>();
      await tester.enterText(field, '2468');
      await tester.pump();
      expect(calls, 2);
      verification.complete(true);
      await tester.pumpAndSettle();
      expect(succeeded, true);
    },
  );

  testWidgets(
    'setup and destructive-action PIN forms require their explicit buttons',
    (tester) async {
      final storage = MemoryStorage();
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(notes.dispose);
      var calls = 0;
      Future<void> pump({required bool fullPage}) => tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notes,
          child: MaterialApp(
            home: Scaffold(
              body: NotePinPrompt(
                key: ValueKey(fullPage),
                fullPage: fullPage,
                title: 'Delete note',
                submitLabel: 'Delete note',
                onSubmit: (pin) async {
                  calls++;
                  return false;
                },
                onSuccess: () {},
              ),
            ),
          ),
        ),
      );
      await pump(fullPage: true);
      await tester.enterText(
        find.widgetWithText(TextField, 'New note PIN'),
        '2468',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm note PIN'),
        '2468',
      );
      await tester.pump();
      expect(calls, 0);
      storage.notePin = '2468';
      await pump(fullPage: false);
      await tester.enterText(
        find.widgetWithText(TextField, 'Note PIN'),
        '2468',
      );
      await tester.pump();
      expect(calls, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Delete note'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
}
