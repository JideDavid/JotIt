import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_it/core/theme/quiet_palette.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/notes/model/note_paper.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/homepage.dart';
import 'package:jot_it/features/notes/view/widgets/note_paper_surface.dart';
import 'support/fakes.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'library mirrors saved paper patterns over card tints in ${brightness.name}',
      (tester) async {
        for (final pattern in NotePaperPattern.values) {
          final paper = NotePaper(
            pattern: pattern,
            tone: NotePaperTone.parchment,
            spacing: 40,
            intensity: 0.16,
          );
          final original = makeNote(
            'styled',
            body: 'Readable preview',
            color: 3,
            paper: paper.encode(),
          );
          final storage = MemoryStorage()..notes = [original];
          final notes = NoteViewModel(
            notesRepo: NotesRepo(localStorageService: storage),
          );
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: notes,
              child: MaterialApp(
                theme: brightness == Brightness.light
                    ? LSTAppTheme.lightTheme
                    : LSTAppTheme.darkTheme,
                home: const Homepage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = find.byKey(const ValueKey('note-styled'));
          final ink = tester.widget<Ink>(
            find.descendant(of: card, matching: find.byType(Ink)),
          );
          final decoration = ink.decoration! as NotePaperDecoration;
          final context = tester.element(card);
          expect(decoration.paper, paper);
          expect(
            decoration.background,
            QuietPalette.of(context).noteSurfaces[3],
          );
          expect(
            decoration.foreground,
            Theme.of(context).colorScheme.onSurface,
          );
          expect(decoration.intensityScale, 0.65);
          expect(find.text('Readable preview'), findsOneWidget);
          expect(storage.notes.single, same(original));
          expect(storage.saveCalls, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          notes.dispose();
        }
      },
    );

    testWidgets(
      'locked cards reveal neither paper nor tint in ${brightness.name}',
      (tester) async {
        final storage = MemoryStorage()
          ..notes = [
            makeNote(
              'private',
              title: 'Secret title',
              body: 'Secret text',
              color: 0xff123456,
              isLocked: true,
              paper: const NotePaper(
                pattern: NotePaperPattern.diamond,
              ).encode(),
            ),
          ];
        final notes = NoteViewModel(
          notesRepo: NotesRepo(localStorageService: storage),
        );
        addTearDown(notes.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: notes,
            child: MaterialApp(
              theme: brightness == Brightness.light
                  ? LSTAppTheme.lightTheme
                  : LSTAppTheme.darkTheme,
              home: const Homepage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('note-private'));
        final ink = tester.widget<Ink>(
          find.descendant(of: card, matching: find.byType(Ink)),
        );
        expect(ink.decoration, isNull);
        final material = tester.widget<Material>(
          find.descendant(of: card, matching: find.byType(Material)).first,
        );
        expect(
          material.color,
          Theme.of(tester.element(card)).colorScheme.surfaceContainer,
        );
        expect(find.text('Locked note'), findsOneWidget);
        expect(find.textContaining('Secret'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('legacy and malformed paper keep plain tinted cards', (
    tester,
  ) async {
    final storage = MemoryStorage()
      ..notes = [makeNote('legacy'), makeNote('invalid', paper: '{broken')];
    final notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: storage),
    );
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notes,
        child: MaterialApp(
          theme: LSTAppTheme.lightTheme,
          home: const Homepage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in ['legacy', 'invalid']) {
      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(ValueKey('note-$id')),
          matching: find.byType(Ink),
        ),
      );
      expect((ink.decoration! as NotePaperDecoration).paper, const NotePaper());
    }
    expect(tester.takeException(), isNull);
  });

  test(
    'card decoration shares the editor painter without changing its tint',
    () async {
      const background = Color(0xffecf2e9);
      const foreground = Color(0xff23262b);
      for (final pattern in NotePaperPattern.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = NotePaperDecoration(
          paper: NotePaper(pattern: pattern),
          background: background,
          foreground: foreground,
          intensityScale: 0.65,
        ).createBoxPainter();
        painter.paint(
          canvas,
          const Offset(8, 8),
          const ImageConfiguration(size: Size(100, 100)),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(120, 120);
        final pixels = (await image.toByteData())!;
        expect(pixels.getUint8(3), 0);
        expect(pixels.getUint8((10 * 120 + 10) * 4 + 3), 255);
        image.dispose();
        picture.dispose();
        painter.dispose();
      }
    },
  );
}
