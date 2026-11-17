import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/notes/model/note_font.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/rich_text_toolbar.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every font family and its license are bundled for offline use',
    () async {
      for (final font in NoteFonts.families) {
        final bytes = await rootBundle.load(
          'assets/fonts/${font.family.replaceAll(' ', '')}-Regular.ttf',
        );
        expect(bytes.getUint32(0), 0x00010000, reason: font.family);
        final license = await rootBundle.loadString(
          'assets/fonts/licenses/${font.sourceSlug}-OFL.txt',
        );
        expect(license, contains('SIL OPEN FONT LICENSE'));
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'font preview, cancel, apply, undo and reopen (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = MemoryStorage();
        final notes = NoteViewModel(
          notesRepo: NotesRepo(localStorageService: storage),
        );
        final controller = notes.bodyController;
        final focus = FocusNode();
        addTearDown(notes.dispose);
        addTearDown(focus.dispose);
        setBodyText(controller, 'Make it bold');
        controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
          ChangeSource.local,
        );
        controller.formatSelection(Attribute.bold);
        controller.formatSelection(const ColorAttribute('#ef5350'));
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? LSTAppTheme.darkTheme : LSTAppTheme.lightTheme,
            localizationsDelegates: const [FlutterQuillLocalizations.delegate],
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: QuillEditor.basic(
                      controller: controller,
                      focusNode: focus,
                    ),
                  ),
                  RichTextToolbar(controller: controller, focusNode: focus),
                ],
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(dark ? 1.6 : 1)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> openFonts() async {
          await tester.ensureVisible(find.byTooltip('Font family'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Font family'));
          await tester.pumpAndSettle();
        }

        Future<void> choose(String slug) async {
          final choice = find.byKey(ValueKey('font-choice-$slug'));
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          await tester.tap(choice);
          await tester.pumpAndSettle();
        }

        final original = controller.document.toDelta().toJson();
        await openFonts();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('font-preview-text')))
              .data,
          'Make',
        );
        await choose('bungee');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('font-preview-text')))
              .style
              ?.fontFamily,
          'Bungee',
        );
        expect(controller.document.toDelta().toJson(), original);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(controller.document.toDelta().toJson(), original);

        await openFonts();
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Serif'));
        await tester.tap(find.widgetWithText(FilterChip, 'Serif'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('font-choice-bungee')), findsNothing);
        await choose('playfairdisplay');
        await tester.tap(find.text('Apply font'));
        await tester.pumpAndSettle();
        final styled = controller.document.toDelta().toJson();
        expect(styled.first['insert'], 'Make');
        expect(
          styled.first['attributes'],
          containsPair('font', 'Playfair Display'),
        );
        expect(styled.first['attributes'], containsPair('bold', true));
        expect(styled.first['attributes'], containsPair('color', '#ef5350'));
        expect(styled.last['attributes']?['font'], isNull);
        expect(
          controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 4),
        );
        controller.undo();
        expect(controller.document.toDelta().toJson(), original);
        controller.redo();
        expect(controller.document.toDelta().toJson(), styled);
        expect(await notes.saveNote(), true);
        expect(jsonDecode(storage.notes.single.richText!), styled);
        notes.setOpenedNote(storage.notes.single);
        await tester.pumpAndSettle();
        expect(controller.document.toDelta().toJson(), styled);
        controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
          ChangeSource.local,
        );
        await openFonts();
        await tester.tap(find.text('Use default'));
        await tester.tap(find.text('Apply font'));
        await tester.pumpAndSettle();
        expect(controller.document.toDelta().toJson(), original);
        controller.updateSelection(
          const TextSelection.collapsed(offset: 12),
          ChangeSource.local,
        );
        await openFonts();
        await tester.ensureVisible(
          find.widgetWithText(FilterChip, 'Handwriting'),
        );
        await tester.tap(find.widgetWithText(FilterChip, 'Handwriting'));
        await tester.pumpAndSettle();
        await choose('caveat');
        await tester.tap(find.text('Apply font'));
        await tester.pumpAndSettle();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'Make it bold new\n',
            selection: TextSelection.collapsed(offset: 16),
          ),
        );
        await tester.pumpAndSettle();
        expect(notes.bodyText, 'Make it bold new');
        expect(
          controller.document.toDelta().toJson().any(
            (op) =>
                op['attributes']?['font'] == 'Caveat' &&
                (op['insert'] as String).contains('new'),
          ),
          true,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
