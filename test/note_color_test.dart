import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/core/theme/quiet_palette.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/model/note_card_color.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/note_color_picker.dart';
import 'support/fakes.dart';

void main() {
  test('custom colors coexist with legacy preset indices and JSON', () {
    for (var index = 0; index < 9; index++) {
      expect(NoteCardColor.normalize(index), index);
      expect(
        Note.fromJson(makeNote('old', color: index).toJson()).color,
        index,
      );
    }
    expect(NoteCardColor.normalize(-1), 0);
    expect(NoteCardColor.normalize(99), 8);
    expect(NoteCardColor.parseHex('#38764c'), 0xff38764c);
    expect(NoteCardColor.parseHex('FFFFFF'), 0xffffffff);
    expect(NoteCardColor.parseHex('#xyzxyz'), isNull);
    expect(NoteCardColor.parseHex('#12ff00ff'), isNull);
    expect(NoteCardColor.hex(0xff000005), '#000005');
    expect(
      Note.fromJson(makeNote('custom', color: 0xff38764c).toJson()).color,
      0xff38764c,
    );
    expect(
      NoteCardColor.favoritesFrom([1, null, 'red', 0xff38764c, 0xff38764c]),
      [0xff38764c],
    );
  });

  test('custom tints preserve readable text in both appearances', () {
    for (final theme in [LSTAppTheme.lightTheme, LSTAppTheme.darkTheme]) {
      final palette = theme.extension<QuietPalette>()!;
      for (var red = 0; red <= 255; red += 51) {
        for (var green = 0; green <= 255; green += 51) {
          for (var blue = 0; blue <= 255; blue += 51) {
            final color = 0xff000000 | red << 16 | green << 8 | blue;
            final surface = palette.cardSurface(color);
            for (final ink in [
              theme.colorScheme.onSurface,
              theme.colorScheme.onSurfaceVariant,
            ]) {
              final luminances = [
                ink.computeLuminance(),
                surface.computeLuminance(),
              ]..sort();
              expect(
                (luminances.last + 0.05) / (luminances.first + 0.05),
                greaterThanOrEqualTo(4.5),
              );
            }
          }
        }
      }
    }
  });

  test(
    'custom tint saves with the note and favorites persist independently',
    () async {
      final storage = MemoryStorage()
        ..notes = [makeNote('sample', body: 'Keep this text')];
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(notes.dispose);
      await notes.getNotesFromLocalStorage();
      notes.setOpenedNote(notes.allNotes.single);
      expect(await notes.toggleFavoriteColor(0xff38764c), true);
      expect(notes.hasUnsavedChanges, false);
      notes.selectColor(0xff123456);
      expect(notes.hasUnsavedChanges, true);
      expect(await notes.saveNote(), true);
      expect(storage.notes.single.color, 0xff123456);
      expect(storage.notes.single.body, 'Keep this text');
      final reopened = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(reopened.dispose);
      reopened.setOpenedNote(storage.notes.single);
      expect(reopened.selectedColor, 0xff123456);
      expect(reopened.favoriteColors, [0xff38764c]);
      reopened.selectColor(3);
      expect(await reopened.saveNote(), true);
      expect(storage.notes.single.color, 3);
    },
  );

  test(
    'favorites reject overlapping writes and retain previous values on failure',
    () async {
      final storage = MemoryStorage();
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(notes.dispose);
      storage.writeBarrier = Completer<void>();
      final writing = notes.toggleFavoriteColor(0xff123456);
      expect(notes.favoriteColors, isEmpty);
      expect(await notes.toggleFavoriteColor(0xffabcdef), false);
      storage.writeBarrier!.complete();
      expect(await writing, true);
      storage.failWrites = true;
      expect(await notes.toggleFavoriteColor(0xff123456), false);
      expect(notes.favoriteColors, [0xff123456]);
      storage.failWrites = false;
      expect(await notes.toggleFavoriteColor(0xff123456), true);
      expect(notes.favoriteColors, isEmpty);
      expect(await notes.toggleFavoriteColor(2), false);
    },
  );

  test('favorite limit never overwrites an existing favorite', () async {
    final storage = MemoryStorage()
      ..favoriteNoteColors = List.generate(24, (index) => 0xff000000 + index);
    final notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: storage),
    );
    addTearDown(notes.dispose);
    expect(await notes.toggleFavoriteColor(0xffabcdef), false);
    expect(notes.favoriteColors, hasLength(24));
    expect(await notes.toggleFavoriteColor(0xff000000), true);
    expect(await notes.toggleFavoriteColor(0xffabcdef), true);
    expect(notes.favoriteColors.last, 0xffabcdef);
  });

  for (final theme in [LSTAppTheme.lightTheme, LSTAppTheme.darkTheme]) {
    testWidgets(
      'wheel, hex, favorites and cancel fit narrow ${theme.brightness.name} layouts',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = MemoryStorage();
        final notes = NoteViewModel(
          notesRepo: NotesRepo(localStorageService: storage),
        );
        addTearDown(notes.dispose);
        int? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async =>
                      result = await showNoteColorPicker(context, notes),
                  child: const Text('Choose color'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose color'));
        await tester.pumpAndSettle();
        final wheel = find.byKey(const ValueKey('note-color-wheel'));
        await tester.ensureVisible(wheel);
        await tester.tapAt(tester.getCenter(wheel) + const Offset(50, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final hex = find.widgetWithText(TextField, 'Hex color');
        await tester.ensureVisible(hex);
        await tester.enterText(hex, '#38764C');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save favorite'));
        await tester.tap(find.text('Save favorite'));
        await tester.pumpAndSettle();
        expect(storage.favoriteNoteColors, [0xff38764c]);
        expect(find.text('Remove favorite'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(notes.selectedColor, 0);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.tap(find.text('Choose color'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Favorite #38764C'));
        await tester.tap(find.byTooltip('Favorite #38764C'));
        await tester.tap(find.text('Apply color'));
        await tester.pumpAndSettle();
        expect(result, 0xff38764c);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
