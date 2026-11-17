import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jot_it/core/theme/appearance_view_model.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/auth/view/app_lock_gate.dart';
import 'package:jot_it/features/auth/view/enable_biometric_page.dart';
import 'package:jot_it/features/auth/view/login_page.dart';
import 'package:jot_it/features/auth/view/pin_login.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/homepage.dart';
import 'package:jot_it/features/notes/view/note_page.dart';
import 'package:jot_it/features/notes/model/note_attachment.dart';
import 'package:jot_it/features/notes/services/note_media_controller.dart';
import 'support/fakes.dart';
import 'support/media_fixtures.dart';
import 'package:jot_it/shared/widgets/pin_auth_modal.dart';
import 'package:jot_it/features/notes/view/widgets/note_pin_prompt.dart';
import 'package:jot_it/views/settings_page.dart';

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('JOTIT_UI_AUDIT')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('ui-audit-canvas')),
    );
    final image = await boundary.toImage();
    try {
      final pixels = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('.dart_tool/ui-audit');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(pixels!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _Fixture {
  _Fixture(ThemeMode mode, {bool lockedNote = false, bool appLock = false}) {
    storage.appearance = mode.name;
    storage.appLock = appLock;
    storage.savedPin = '1234';
    storage.notePin = lockedNote ? '2468' : '';
    storage.notes = [
      makeNote(
        'sample',
        title: 'A quiet thought',
        body: 'Plain words',
        isLocked: lockedNote,
      ),
    ];
    appearance = AppearanceViewModel(storage);
    notes = NoteViewModel(notesRepo: NotesRepo(localStorageService: storage));
    auth = AuthViewModel(
      authRepository: TestAuthRepository(storage),
      localBiometricService: biometrics,
      internetCheckerService: connection,
    );
  }

  final storage = MemoryStorage();
  final biometrics = TestBiometrics();
  final connection = TestConnection();
  late final AppearanceViewModel appearance;
  late final NoteViewModel notes;
  late final AuthViewModel auth;

  Future<void> pump(
    WidgetTester tester, {
    Widget home = const Homepage(),
    bool large = false,
  }) async {
    ThemeData auditTheme(ThemeData theme) =>
        const bool.fromEnvironment('JOTIT_UI_AUDIT')
        ? theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'JotItAudit'),
            appBarTheme: theme.appBarTheme.copyWith(
              titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: 'JotItAudit',
              ),
            ),
            dialogTheme: theme.dialogTheme.copyWith(
              titleTextStyle: theme.dialogTheme.titleTextStyle?.copyWith(
                fontFamily: 'JotItAudit',
              ),
              contentTextStyle: theme.dialogTheme.contentTextStyle?.copyWith(
                fontFamily: 'JotItAudit',
              ),
            ),
            popupMenuTheme: theme.popupMenuTheme.copyWith(
              textStyle: theme.popupMenuTheme.textStyle?.copyWith(
                fontFamily: 'JotItAudit',
              ),
            ),
            chipTheme: theme.chipTheme.copyWith(
              labelStyle: theme.chipTheme.labelStyle?.copyWith(
                fontFamily: 'JotItAudit',
              ),
            ),
          )
        : theme;
    tester.view.physicalSize = large
        ? const Size(320, 640)
        : const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appearance),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: auditTheme(LSTAppTheme.lightTheme),
            darkTheme: auditTheme(LSTAppTheme.darkTheme),
            themeMode: context.watch<AppearanceViewModel>().mode,
            localizationsDelegates: const [FlutterQuillLocalizations.delegate],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 1.6 : 1)),
              child: RepaintBoundary(
                key: const ValueKey('ui-audit-canvas'),
                child: child!,
              ),
            ),
            home: AppLockGate(child: home),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('note-sample')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('note-sample'))) +
          const Offset(30, 30),
    );
    await tester.pumpAndSettle();
  }

  Future<void> format(WidgetTester tester, String label) async {
    final tool = find.byTooltip(label);
    await tester.ensureVisible(tool);
    await tester.pumpAndSettle();
    await tester.tap(tool);
    await tester.pumpAndSettle();
  }

  void dispose() {
    notes.dispose();
    auth.dispose();
    appearance.dispose();
    connection.dispose();
  }
}

void main() {
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('JOTIT_AUDIT_FONTS');
    if (fontDirectory.isEmpty) return;
    final text = FontLoader('JotItAudit');
    for (final name in ['regular', 'bold', 'medium', 'italic']) {
      text.addFont(
        File(
          '$fontDirectory/roboto-$name.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await text.load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            '$fontDirectory/materialicons-regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'library header stays fixed and content clears system navigation in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        fixture.storage.notes = List.generate(
          20,
          (index) => makeNote(
            'item-$index',
            title: 'Thought $index',
            body: 'A short preview of this thought.',
            timestamp: DateTime.utc(2026, 1, 20 - index),
          ),
        );
        await fixture.pump(tester);
        final settings = find.byTooltip('Settings');
        final headerPosition = tester.getTopLeft(settings);
        expect(headerPosition.dy, greaterThanOrEqualTo(24));
        expect(
          tester.getSize(find.byKey(const ValueKey('note-item-0'))).height,
          lessThan(140),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('note-item-19')),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(settings), headerPosition);
        expect(settings.hitTestable(), findsOneWidget);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        final safeBottom = 850 - 48;
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('note-item-19'))).dy,
          lessThanOrEqualTo(safeBottom),
        );
        expect(
          tester.getBottomLeft(find.byType(FloatingActionButton)).dy,
          lessThanOrEqualTo(safeBottom),
        );
        await tester.tap(settings);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -1600));
        await tester.pumpAndSettle();
        expect(
          tester
              .getBottomLeft(find.textContaining('Notes are currently stored'))
              .dy,
          lessThanOrEqualTo(safeBottom),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'editor tools and sheets clear system navigation in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await fixture.pump(tester, large: true);
        await fixture.openEditor(tester);
        final safeBottom = 640 - 48;
        expect(
          tester
              .getBottomLeft(find.byKey(const ValueKey('note-save-status')))
              .dy,
          lessThanOrEqualTo(safeBottom),
        );
        expect(find.byTooltip('Undo').hitTestable(), findsOneWidget);
        expect(find.byTooltip('Redo').hitTestable(), findsOneWidget);
        final history = find.byKey(const ValueKey('note-history-controls'));
        final rail = find.byKey(const ValueKey('formatting-toolbar'));
        expect(
          tester.getBottomLeft(history).dy,
          lessThan(tester.getTopLeft(rail).dy),
        );
        expect(
          tester.getTopLeft(history).dy,
          greaterThanOrEqualTo(tester.getTopLeft(find.byType(QuillEditor)).dy),
        );
        expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.redo))
              .onPressed,
          isNull,
        );
        await fixture.format(tester, 'Headings');
        final formattingScroll = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SingleChildScrollView),
        );
        expect(
          tester.getBottomLeft(formattingScroll).dy,
          lessThanOrEqualTo(safeBottom),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Attach image or audio'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cancel'));
        expect(
          tester.getBottomLeft(find.widgetWithText(TextButton, 'Cancel')).dy,
          lessThanOrEqualTo(safeBottom),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        for (final label in ['Undo', 'Redo', 'Next formatting tools']) {
          expect(find.byTooltip(label).hitTestable(), findsOneWidget);
          expect(
            tester.getBottomLeft(find.byTooltip(label)).dy,
            lessThanOrEqualTo(340),
          );
        }
        expect(
          tester.getBottomLeft(history).dy,
          lessThan(tester.getTopLeft(rail).dy),
        );
        expect(
          tester.getTopLeft(history).dy,
          greaterThanOrEqualTo(tester.getTopLeft(find.byType(QuillEditor)).dy),
        );
        await _capture(tester, 'floating-history-keyboard-${mode.name}');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'scrolling rail and formatting dialogs preserve selection in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await _capture(tester, 'library-${mode.name}');
        await fixture.openEditor(tester);
        await _capture(tester, 'editor-${mode.name}');
        final rail = find.byKey(const ValueKey('formatting-toolbar'));
        final strip = find.byKey(const ValueKey('formatting-scroll-strip'));
        expect(
          tester.widget<SingleChildScrollView>(strip).scrollDirection,
          Axis.horizontal,
        );
        expect(tester.getSize(rail).height, 48);
        final scroll = tester.widget<SingleChildScrollView>(strip).controller!;
        await tester.tap(find.byTooltip('Next formatting tools'));
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(0));
        await tester.tap(find.byTooltip('Previous formatting tools'));
        await tester.pumpAndSettle();
        expect(scroll.offset, 0);
        final history = find.byKey(const ValueKey('note-history-controls'));
        expect(
          tester.getBottomLeft(history).dy,
          lessThan(tester.getTopLeft(rail).dy),
        );
        for (final label in ['Undo', 'Redo']) {
          expect(
            find.descendant(of: rail, matching: find.byTooltip(label)),
            findsNothing,
          );
          expect(
            find.descendant(of: history, matching: find.byTooltip(label)),
            findsOneWidget,
          );
        }
        expect(find.byTooltip('Strikethrough'), findsOneWidget);
        fixture.notes.bodyController.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 11),
          ChangeSource.local,
        );
        await tester.drag(strip, const Offset(-240, 0));
        await tester.pumpAndSettle();
        expect(
          fixture.notes.bodyController.selection,
          const TextSelection(baseOffset: 0, extentOffset: 11),
        );
        await tester.ensureVisible(find.byTooltip('Strikethrough'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Strikethrough'));
        await tester.pumpAndSettle();
        expect(
          fixture.notes.bodyController.document
              .toDelta()
              .toJson()
              .first['attributes'],
          containsPair('strike', true),
        );
        expect(find.text('Formatting'), findsNothing);
        await tester.tap(find.byTooltip('Undo'));
        await tester.pumpAndSettle();
        expect(
          fixture.notes.bodyController.document
              .toDelta()
              .toJson()
              .first['attributes']?['strike'],
          isNot(true),
        );
        await tester.tap(find.byTooltip('Redo'));
        await tester.pumpAndSettle();
        expect(
          fixture.notes.bodyController.document
              .toDelta()
              .toJson()
              .first['attributes'],
          containsPair('strike', true),
        );
        fixture.notes.bodyController.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 11),
          ChangeSource.local,
        );
        await fixture.format(tester, 'Headings');
        await _capture(tester, 'headings-${mode.name}');
        await tester.tap(find.text('Heading 2'));
        await tester.pumpAndSettle();
        expect(
          fixture.notes.bodyController.document.toDelta().toJson().any(
            (operation) => operation['attributes']?['header'] == 2,
          ),
          true,
        );
        expect(
          fixture.notes.bodyController.selection,
          const TextSelection(baseOffset: 0, extentOffset: 11),
        );
        await fixture.format(tester, 'Font size');
        await tester.tap(find.text('Large — 24'));
        await tester.pumpAndSettle();
        expect(
          fixture.notes.bodyController.document
              .toDelta()
              .toJson()
              .first['attributes'],
          containsPair('size', '24'),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'paragraph tools remain functional through the ${mode.name} formatting rail',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await fixture.openEditor(tester);
        for (final tool in [
          ('Bulleted list', 'list', 'bullet'),
          ('Numbered list', 'list', 'ordered'),
          ('Checklist', 'list', 'unchecked'),
          ('Quote', 'blockquote', true),
        ]) {
          fixture.notes.bodyController.updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 11),
            ChangeSource.local,
          );
          await fixture.format(tester, tool.$1);
          expect(
            fixture.notes.bodyController.document.toDelta().toJson().any(
              (operation) => operation['attributes']?[tool.$2] == tool.$3,
            ),
            true,
          );
        }
        expect(fixture.notes.bodyText, 'Plain words');
        expect(fixture.notes.hasUnsavedChanges, true);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'note actions and formatting dialogs reflow at 320px in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        await fixture.pump(tester, large: true);
        await fixture.openEditor(tester);
        await tester.tap(find.byTooltip('Note actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Note card color'));
        await tester.pumpAndSettle();
        await _capture(tester, 'colors-narrow-${mode.name}');
        await tester.ensureVisible(find.byTooltip('Color 3'));
        await tester.tap(find.byTooltip('Color 3'));
        await tester.tap(find.text('Apply color'));
        await tester.pumpAndSettle();
        expect(fixture.notes.selectedColor, 2);
        expect(fixture.notes.bodyText, 'Plain words');
        await fixture.format(tester, 'Clear formatting');
        await tester.ensureVisible(find.byTooltip('Color & highlight'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Color & highlight'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Text color'));
        await tester.pumpAndSettle();
        await _capture(tester, 'text-colors-${mode.name}');
        expect(find.text('Red'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Red'));
        await tester.tap(find.byTooltip('Red'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Insert or edit link'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Insert or edit link'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, 'link-keyboard-${mode.name}');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dedicated note unlock reflows above the keyboard in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode, lockedNote: true);
        addTearDown(fixture.dispose);
        await fixture.pump(tester, large: true);
        await fixture.openEditor(tester);
        expect(find.byKey(const ValueKey('note-unlock-page')), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(NotePage), findsNothing);
        expect(find.text('Plain words'), findsNothing);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.widgetWithText(TextField, 'Note PIN'),
          '0000',
        );
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        expect(find.text('Incorrect note PIN.'), findsOneWidget);
        await _capture(tester, 'note-unlock-error-${mode.name}');
        expect(fixture.notes.needsNoteUnlock, true);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('inline images and audio fit large text in ${mode.name}', (
      tester,
    ) async {
      final fixture = _Fixture(mode);
      addTearDown(fixture.dispose);
      await fixture.pump(tester, large: true);
      await fixture.openEditor(tester);
      final image = await tester.runAsync(samplePng);
      expect(
        fixture.notes.attachMedia(
          NoteAttachment(
            id: 'image',
            name: 'Reference image.png',
            mimeType: 'image/png',
            bytes: image!,
          ),
        ),
        true,
      );
      expect(
        fixture.notes.attachMedia(
          NoteAttachment(
            id: 'audio',
            name: 'A thought to keep.wav',
            mimeType: 'audio/wav',
            bytes: NoteMediaController.wavFromPcm(image),
          ),
        ),
        true,
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove attachment'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await _capture(tester, 'media-${mode.name}');
      final viewImage = find.byTooltip('View image Reference image.png');
      await tester.ensureVisible(viewImage);
      await tester.tap(viewImage);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('Close image'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close image'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Attach image or audio'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Record voice note'));
      await tester.tap(find.text('Record voice note'));
      await tester.pumpAndSettle();
      expect(find.text('Start recording'), findsOneWidget);
      await _capture(tester, 'recorder-${mode.name}');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fixture.notes.attachments, hasLength(2));
    });

    testWidgets(
      'account and biometric screens fit large text in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        await fixture.pump(tester, home: const LoginPage(), large: true);
        expect(find.text('Continue with local notes'), findsOneWidget);
        expect(find.textContaining('not enabled'), findsOneWidget);
        await _capture(tester, 'account-narrow-${mode.name}');
        expect(tester.takeException(), isNull);
        await fixture.pump(
          tester,
          home: const EnableBiometricPage(),
          large: true,
        );
        expect(find.text('Unlock with\na touch'), findsOneWidget);
        await _capture(tester, 'biometrics-narrow-${mode.name}');
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Enable biometrics'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('appearance never bypasses App Lock in ${mode.name}', (
      tester,
    ) async {
      final fixture = _Fixture(mode, appLock: true);
      addTearDown(fixture.dispose);
      await fixture.pump(tester, large: true);
      expect(find.byType(PinLogin), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Unlock'), findsNothing);
      for (final size in [
        const Size(320, 568),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final viewport = Offset.zero & size;
        for (final element in [
          find.text('Unlock JotIt'),
          find.text('Your app PIN is separate from your shared note PIN.'),
          find.byTooltip('Delete PIN digit'),
          find.byTooltip('Unlock with biometrics'),
          for (var digit = 0; digit <= 9; digit++)
            find.widgetWithText(TextButton, '$digit'),
        ]) {
          final bounds = tester.getRect(element);
          expect(viewport.contains(bounds.topLeft), isTrue);
          expect(viewport.contains(bounds.bottomRight), isTrue);
        }
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await _capture(tester, 'app-unlock-narrow-${mode.name}');
      await fixture.appearance.setMode(
        mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      );
      await tester.pumpAndSettle();
      expect(fixture.auth.isLocked, true);
      expect(find.byType(PinLogin), findsOneWidget);
      expect(find.text('A quiet thought'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'security dialogs fit enlarged text above the keyboard in ${mode.name}',
      (tester) async {
        final fixture = _Fixture(mode);
        addTearDown(fixture.dispose);
        await fixture.pump(
          tester,
          large: true,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => PinInputModal.setPin(context),
                    child: const Text('Review setup'),
                  ),
                  TextButton(
                    onPressed: () => PinInputModal.removePin(context),
                    child: const Text('Review removal'),
                  ),
                  TextButton(
                    onPressed: () => showNotePinPrompt(
                      context,
                      title: 'Lock note',
                      submitLabel: 'Lock note',
                      onSubmit: (_) async => false,
                    ),
                    child: const Text('Review note lock'),
                  ),
                ],
              ),
            ),
          ),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        for (final form in [
          ('Review setup', 'Set App Lock PIN'),
          ('Review removal', 'Disable App Lock'),
          ('Review note lock', 'Lock note'),
        ]) {
          await tester.tap(find.text(form.$1));
          await tester.pumpAndSettle();
          expect(find.text(form.$2), findsWidgets);
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            '${form.$1.replaceAll(' ', '-')}-${mode.name}',
          );
          final field = find.byType(TextField).first;
          await tester.ensureVisible(field);
          await tester.enterText(field, '12');
          await tester.pumpAndSettle();
          expect(field.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'background note locking covers the heading dialog and retains the draft',
    (tester) async {
      final fixture = _Fixture(ThemeMode.dark, lockedNote: true);
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await fixture.openEditor(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Note PIN'),
        '2468',
      );
      await tester.pumpAndSettle();
      setBodyText(fixture.notes.bodyController, 'Private unsaved text');
      await fixture.format(tester, 'Headings');
      expect(find.text('Headings'), findsOneWidget);
      fixture.notes.handleLifecycle(AppLifecycleState.paused);
      fixture.notes.handleLifecycle(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Headings'), findsNothing);
      expect(find.byType(NotePage), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Note PIN'),
        '2468',
      );
      await tester.pumpAndSettle();
      expect(find.text('Headings'), findsOneWidget);
      expect(fixture.notes.bodyText, 'Private unsaved text');
    },
  );
}
