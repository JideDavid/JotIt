import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/model/note_paper.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/note_paper_picker.dart';
import 'package:jot_it/features/notes/view/widgets/note_paper_surface.dart';
import 'support/fakes.dart';

void main() {
  const styledPaper = NotePaper(
    pattern: NotePaperPattern.dots,
    tone: NotePaperTone.parchment,
    spacing: 32,
    intensity: 0.14,
  );

  test('paper round-trips JSON and old notes keep plain paper', () {
    expect(NotePaper.decode(styledPaper.encode()), styledPaper);
    expect(const NotePaper().encode(), isNull);
    final note = makeNote('paper', paper: styledPaper.encode());
    expect(Note.fromJson(note.toJson()).paper, note.paper);
    expect(
      NotePaper.decode(Note.fromJson({'id': 'old'}).paper),
      const NotePaper(),
    );
    expect(Note.fromJson({'paper': 123}).paper, isNull);
  });

  test(
    'malformed settings safely fall back and numeric values are bounded',
    () {
      for (final encoded in [null, '{broken', '[]', 'null', '{"version":2}']) {
        expect(NotePaper.decode(encoded), const NotePaper());
      }
      final bounded = NotePaper.decode(
        jsonEncode({
          'version': 1,
          'pattern': 'unknown',
          'tone': 'unknown',
          'spacing': -100,
          'intensity': 500,
        }),
      );
      expect(bounded.pattern, NotePaperPattern.plain);
      expect(bounded.tone, NotePaperTone.theme);
      expect(bounded.spacing, 16);
      expect(bounded.intensity, 0.20);
      final invalidTypes = NotePaper.decode(
        '{"version":1,"spacing":"huge","intensity":null}',
      );
      expect(invalidTypes, const NotePaper());
    },
  );

  group('paper persistence', () {
    late MemoryStorage storage;
    late NoteViewModel notes;

    setUp(() {
      storage = MemoryStorage();
      notes = NoteViewModel(notesRepo: NotesRepo(localStorageService: storage));
    });
    tearDown(() => notes.dispose());

    test(
      'background-only changes save without rewriting rich text or card color',
      () async {
        final original = makeNote(
          'styled',
          body: 'Styled text',
          color: 3,
          richText:
              '[{"insert":"Styled text","attributes":{"bold":true,"color":"#ef5350"}},{"insert":"\\n"}]',
        );
        storage.notes = [original];
        await notes.getNotesFromLocalStorage();
        notes.setOpenedNote(original);
        final delta = notes.bodyController.document.toDelta().toJson();
        notes.selectPaper(styledPaper);
        expect(notes.hasUnsavedChanges, true);
        expect(await notes.saveNote(), true);
        final saved = storage.notes.single;
        expect(saved.body, original.body);
        expect(saved.color, original.color);
        expect(jsonDecode(saved.richText!), delta);
        expect(NotePaper.decode(saved.paper), styledPaper);
        notes.setOpenedNote(saved);
        expect(notes.paper, styledPaper);
        expect(notes.hasUnsavedChanges, false);
        notes.selectPaper(const NotePaper());
        expect(notes.hasUnsavedChanges, true);
        expect(await notes.saveNote(), true);
        expect(storage.notes.single.paper, isNull);
        notes.setOpenedNote(null);
        expect(notes.paper, const NotePaper());
      },
    );

    test('failed writes retain paper draft and retry saves it', () async {
      final original = makeNote('original', body: 'Keep me');
      storage.notes = [original];
      await notes.getNotesFromLocalStorage();
      notes.setOpenedNote(original);
      notes.selectPaper(styledPaper);
      storage.failWrites = true;
      expect(await notes.saveNote(), false);
      expect(storage.notes.single.paper, isNull);
      expect(notes.paper, styledPaper);
      expect(notes.hasUnsavedChanges, true);
      storage.failWrites = false;
      expect(await notes.saveNote(), true);
      expect(notes.hasUnsavedChanges, false);
    });

    test(
      'paper edited during a pending save remains unsaved afterward',
      () async {
        notes.titleController.text = 'Draft';
        notes.selectPaper(styledPaper);
        storage.writeBarrier = Completer<void>();
        final saving = notes.saveNote();
        final nextPaper = styledPaper.copyWith(pattern: NotePaperPattern.ruled);
        notes.selectPaper(nextPaper);
        storage.writeBarrier!.complete();
        expect(await saving, true);
        expect(NotePaper.decode(storage.notes.single.paper), styledPaper);
        expect(notes.paper, nextPaper);
        expect(notes.hasUnsavedChanges, true);
        expect(await notes.saveNote(), true);
        expect(notes.hasUnsavedChanges, false);
      },
    );

    test('locking and re-locking retain paper and formatting drafts', () async {
      notes.titleController.text = 'Private';
      setBodyText(notes.bodyController, 'Secret');
      notes.bodyController.formatText(0, 6, Attribute.bold);
      notes.selectPaper(styledPaper);
      expect(await notes.changeOpenedNoteLock('1234', locked: true), true);
      expect(NotePaper.decode(storage.notes.single.paper), styledPaper);
      final nextPaper = styledPaper.copyWith(tone: NotePaperTone.mist);
      notes.selectPaper(nextPaper);
      notes.handleLifecycle(AppLifecycleState.paused);
      notes.handleLifecycle(AppLifecycleState.resumed);
      expect(await notes.unlockOpenedNote('1234'), true);
      expect(notes.paper, nextPaper);
      expect(notes.hasUnsavedChanges, true);
      expect(await notes.changeOpenedNoteLock('1234', locked: false), true);
      expect(NotePaper.decode(storage.notes.single.paper), nextPaper);
      expect(storage.notes.single.richText, contains('bold'));
    });

    test(
      'blank styled drafts prompt before leaving but cannot create empty notes',
      () async {
        notes.setOpenedNote(null);
        notes.selectPaper(styledPaper);
        expect(notes.hasUnsavedChanges, true);
        expect(await notes.saveNote(), false);
        expect(storage.notes, isEmpty);
        notes.setOpenedNote(null);
        expect(notes.hasUnsavedChanges, false);
      },
    );
  });

  test('paper tones keep readable foregrounds in both themes', () {
    for (final brightness in Brightness.values) {
      final theme = ThemeData(brightness: brightness);
      for (final tone in NotePaperTone.values) {
        final surface = NotePaperSurface.backgroundFor(tone, theme);
        final ink = NotePaperSurface.foregroundFor(tone, theme);
        final luminances = [surface.computeLuminance(), ink.computeLuminance()]
          ..sort();
        expect(
          (luminances.last + 0.05) / (luminances.first + 0.05),
          greaterThan(4.5),
        );
      }
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'paper picker fits narrow screens and large text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        NotePaper? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => result = await showNotePaperPicker(
                    context,
                    const NotePaper(),
                  ),
                  child: const Text('Open paper'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open paper'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Dotted'));
        await tester.tap(find.text('Dotted'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NotePaperSurface>(
                find.byKey(const ValueKey('paper-live-preview')),
              )
              .paper
              .pattern,
          NotePaperPattern.dots,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.tap(find.text('Open paper'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ruled'));
        await tester.tap(find.text('Ruled'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply paper'));
        await tester.pumpAndSettle();
        expect(result?.pattern, NotePaperPattern.ruled);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('paper controls preview customization, reset, and apply', (
    tester,
  ) async {
    NotePaper? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showNotePaperPicker(
                context,
                const NotePaper(),
              ),
              child: const Text('Open paper'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open paper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dotted'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sage'));
    await tester.tap(find.text('Sage'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('paper-spacing')));
    await tester.drag(
      find.byKey(const ValueKey('paper-spacing')),
      const Offset(80, 0),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('paper-intensity')));
    await tester.drag(
      find.byKey(const ValueKey('paper-intensity')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    final preview = tester
        .widget<NotePaperSurface>(
          find.byKey(const ValueKey('paper-live-preview')),
        )
        .paper;
    expect(preview.pattern, NotePaperPattern.dots);
    expect(preview.tone, NotePaperTone.sage);
    expect(preview.spacing, isNot(28));
    expect(preview.intensity, isNot(0.10));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<NotePaperSurface>(
            find.byKey(const ValueKey('paper-live-preview')),
          )
          .paper,
      const NotePaper(),
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('paper-spacing')))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('paper-intensity')))
          .onChanged,
      isNull,
    );
    await tester.tap(find.text('Apply paper'));
    await tester.pumpAndSettle();
    expect(result, const NotePaper());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'every paper pattern paints in both appearances and while scrolling',
    (tester) async {
      for (final brightness in Brightness.values) {
        for (final pattern in NotePaperPattern.values) {
          final scroll = ScrollController();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: NotePaperSurface(
                  paper: styledPaper.copyWith(pattern: pattern),
                  scrollController: scroll,
                  child: ListView(
                    controller: scroll,
                    children: const [SizedBox(height: 1500)],
                  ),
                ),
              ),
            ),
          );
          scroll.jumpTo(79);
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          scroll.dispose();
        }
      }
    },
  );
}
