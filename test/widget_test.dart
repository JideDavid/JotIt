import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/core/theme/appearance_view_model.dart';
import 'package:jot_it/core/utils/size_config.dart';
import 'package:jot_it/features/auth/view/app_lock_gate.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/homepage.dart';
import 'package:jot_it/features/notes/view/note_page.dart';
import 'package:jot_it/features/notes/model/note_paper.dart';
import 'package:jot_it/features/notes/view/widgets/note_paper_surface.dart';
import 'package:jot_it/main.dart';
import 'package:jot_it/views/settings_page.dart';
import 'support/fakes.dart';

void main() {
  late MemoryStorage storage;
  late NoteViewModel notes;
  late TestBiometrics biometrics;
  late TestConnection connection;
  AuthViewModel? auth;
  AppearanceViewModel? appearance;

  setUp(() {
    storage = MemoryStorage();
    notes = NoteViewModel(notesRepo: NotesRepo(localStorageService: storage));
    biometrics = TestBiometrics();
    connection = TestConnection();
    auth = null;
  });
  tearDown(() {
    notes.dispose();
    auth?.dispose();
    appearance?.dispose();
    connection.dispose();
  });

  Future<void> pumpApp(WidgetTester tester, {bool realStartup = false}) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    auth = AuthViewModel(
      authRepository: TestAuthRepository(storage),
      localBiometricService: biometrics,
      internetCheckerService: connection,
    );
    appearance = AppearanceViewModel(storage);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: auth!),
          ChangeNotifierProvider.value(value: appearance!),
        ],
        child: realStartup
            ? const MyApp()
            : MaterialApp(
                theme: LSTAppTheme.lightTheme,
                darkTheme: LSTAppTheme.darkTheme,
                themeMode: ThemeMode.dark,
                localizationsDelegates: const [
                  FlutterQuillLocalizations.delegate,
                ],
                home: Builder(
                  builder: (context) {
                    SizeConfig().init(context);
                    return const AppLockGate(child: Homepage());
                  },
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unlock(WidgetTester tester) async {
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> backgroundAndResume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  Future<void> tapFormat(WidgetTester tester, String tooltip) async {
    if (tooltip == 'Text color' || tooltip == 'Highlight') {
      await tester.ensureVisible(find.byTooltip('Color & highlight'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Color & highlight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tooltip));
      await tester.pumpAndSettle();
      return;
    }
    final button = find.byTooltip(tooltip);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> enterNotePin(WidgetTester tester, String pin) async {
    await tester.enterText(find.widgetWithText(TextField, 'Note PIN'), pin);
  }

  testWidgets('note PIN screen fits a narrow phone with the keyboard visible', (
    tester,
  ) async {
    storage.notePin = '1234';
    storage.notes = [makeNote('private', isLocked: true)];
    await pumpApp(tester);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-private')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await enterNotePin(tester, '123');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('This note is locked'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Unlock note'), findsNothing);
  });

  testWidgets(
    'paper changes use save/discard and the style rail stays below the editor',
    (tester) async {
      storage.notes = [makeNote('paper', body: 'Keep my text')];
      await pumpApp(tester);
      await tester.tap(find.text('paper'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(QuillEditor)).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const ValueKey('bottom-style-rail'))).dy,
        ),
      );
      await tester.tap(find.byTooltip('Paper style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dotted'));
      await tester.tap(find.text('Apply paper'));
      await tester.pumpAndSettle();
      expect(notes.paper.pattern, NotePaperPattern.dots);
      expect(notes.hasUnsavedChanges, true);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('paper'));
      await tester.pumpAndSettle();
      expect(notes.paper, const NotePaper());
      await tester.tap(find.byTooltip('Paper style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grid'));
      await tester.tap(find.text('Apply paper'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('paper'));
      await tester.pumpAndSettle();
      expect(notes.paper.pattern, NotePaperPattern.grid);
      expect(notes.bodyText, 'Keep my text');
      expect(notes.hasUnsavedChanges, false);
      expect(find.byType(NotePaperSurface), findsOneWidget);
    },
  );

  testWidgets(
    'paper picker remains covered by the note lock and preserves its selection',
    (tester) async {
      storage.notePin = '1234';
      storage.notes = [makeNote('private', body: 'Secret', isLocked: true)];
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('note-private')));
      await tester.pumpAndSettle();
      await enterNotePin(tester, '1234');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Paper style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dotted'));
      await backgroundAndResume(tester);
      expect(find.text('Apply paper'), findsNothing);
      await enterNotePin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text('Apply paper'), findsOneWidget);
      await tester.tap(find.text('Apply paper'));
      await tester.pumpAndSettle();
      expect(notes.paper.pattern, NotePaperPattern.dots);
      expect(notes.bodyText, 'Secret');
    },
  );

  testWidgets('a shared PIN locks notes, hides titles and protects reopening', (
    tester,
  ) async {
    storage.notes = [
      makeNote('private', title: 'Hidden title', body: 'Hidden body'),
    ];
    await pumpApp(tester);
    await tester.tap(find.text('Hidden title'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'New note PIN'),
      '1234',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm note PIN'),
      '9999',
    );
    await tester.tap(find.text('Save and lock'));
    await tester.pumpAndSettle();
    expect(find.text('PINs do not match.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm note PIN'),
      '1234',
    );
    await tester.tap(find.text('Save and lock'));
    await tester.pumpAndSettle();
    expect(storage.notes.single.isLocked, true);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hidden title'), findsNothing);
    expect(find.text('Hidden body'), findsNothing);
    expect(find.text('Locked note'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hidden');
    await tester.pumpAndSettle();
    expect(find.text('No notes found'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-private')));
    await tester.pumpAndSettle();
    expect(find.byType(NotePage), findsNothing);
    await enterNotePin(tester, '9999');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect note PIN.'), findsOneWidget);
    await enterNotePin(tester, '1234');
    await tester.pumpAndSettle();
    expect(find.byType(NotePage), findsOneWidget);
    expect(notes.titleController.text, 'Hidden title');
    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove note lock'));
    await tester.pumpAndSettle();
    await enterNotePin(tester, '1234');
    await tester.tap(find.widgetWithText(TextButton, 'Remove lock'));
    await tester.pumpAndSettle();
    expect(storage.notes.single.isLocked, false);
  });

  testWidgets('deleting a locked note requires the shared PIN', (tester) async {
    storage.notePin = '1234';
    storage.notes = [makeNote('private', title: 'Secret', isLocked: true)];
    await pumpApp(tester);
    await tester.longPress(find.byKey(const ValueKey('note-private')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await enterNotePin(tester, '0000');
    await tester.tap(find.widgetWithText(TextButton, 'Delete note'));
    await tester.pumpAndSettle();
    expect(storage.notes, hasLength(1));
    expect(find.text('Incorrect note PIN.'), findsOneWidget);
    await enterNotePin(tester, '1234');
    await tester.tap(find.widgetWithText(TextButton, 'Delete note'));
    await tester.pumpAndSettle();
    expect(storage.notes, isEmpty);
    expect(find.text('Create your first note!'), findsOneWidget);
  });

  testWidgets(
    'note re-locking covers formatting dialogs and preserves the draft without App Lock',
    (tester) async {
      storage.notePin = '1234';
      storage.notes = [makeNote('private', body: 'Saved body', isLocked: true)];
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('note-private')));
      await tester.pumpAndSettle();
      await enterNotePin(tester, '1234');
      await tester.pumpAndSettle();
      setBodyText(notes.bodyController, 'Unsaved secret');
      await tapFormat(tester, 'Insert or edit link');
      expect(find.widgetWithText(TextField, 'URL'), findsOneWidget);
      await backgroundAndResume(tester);
      expect(find.widgetWithText(TextField, 'URL'), findsNothing);
      expect(find.byType(NotePage), findsNothing);
      expect(find.byTooltip('Back to notes'), findsNothing);
      await enterNotePin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'URL'), findsOneWidget);
      expect(notes.bodyText, 'Unsaved secret');
      expect(notes.hasUnsavedChanges, true);
    },
  );

  testWidgets(
    'App Lock unlock does not bypass a locked note and opening can be cancelled',
    (tester) async {
      storage.notePin = '2468';
      storage.savedPin = '1234';
      storage.appLock = true;
      storage.notes = [makeNote('private', isLocked: true)];
      await pumpApp(tester);
      await unlock(tester);
      await tester.tap(find.byKey(const ValueKey('note-private')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to notes'));
      await tester.pumpAndSettle();
      expect(find.byType(Homepage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-private')));
      await tester.pumpAndSettle();
      await enterNotePin(tester, '2468');
      await tester.pumpAndSettle();
      await backgroundAndResume(tester);
      await unlock(tester);
      expect(find.text('This note is locked'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Unlock note'), findsNothing);
      expect(find.byType(NotePage), findsNothing);
    },
  );

  testWidgets('activating bold before typing styles new keyboard input', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tapFormat(tester, 'Bold');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Bold typing\n',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    await tester.pumpAndSettle();
    expect(notes.bodyText, 'Bold typing');
    expect(
      notes.bodyController.document.toDelta().toJson().first['attributes'],
      containsPair('bold', true),
    );
  });

  testWidgets(
    'toolbar styles, colors, highlights, and links survive reopening a note',
    (tester) async {
      storage.notes = [makeNote('styled', body: 'Format me')];
      await pumpApp(tester);
      await tester.tap(find.text('styled'));
      await tester.pumpAndSettle();
      notes.bodyController.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 9),
        ChangeSource.local,
      );
      await tapFormat(tester, 'Bold');
      await tapFormat(tester, 'Underline');
      await tapFormat(tester, 'Text color');
      await tester.tap(find.byTooltip('Red'));
      await tester.pumpAndSettle();
      await tapFormat(tester, 'Highlight');
      await tester.tap(find.byTooltip('Yellow'));
      await tester.pumpAndSettle();
      await tapFormat(tester, 'Insert or edit link');
      await tester.enterText(
        find.widgetWithText(TextField, 'URL'),
        'example.com',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final attributes =
          notes.bodyController.document.toDelta().toJson().first['attributes']
              as Map;
      expect(attributes['bold'], true);
      expect(attributes['underline'], true);
      expect(attributes['color'], '#ef5350');
      expect(attributes['background'], '#ffeb3b');
      expect(attributes['link'], 'https://example.com');
      expect(notes.hasUnsavedChanges, true);
      await tester.tap(find.byTooltip('Save note'));
      await tester.pumpAndSettle();
      final savedDelta = storage.notes.single.richText;
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('styled'));
      await tester.pumpAndSettle();
      expect(
        notes.bodyController.document.toDelta().toJson(),
        jsonDecode(savedDelta!),
      );
      expect(notes.hasUnsavedChanges, false);
    },
  );

  testWidgets(
    'formatting alone prompts to save, and clear formatting restores plain text',
    (tester) async {
      storage.notes = [makeNote('plain', body: 'Text')];
      await pumpApp(tester);
      await tester.tap(find.text('plain'));
      await tester.pumpAndSettle();
      notes.bodyController.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4),
        ChangeSource.local,
      );
      await tapFormat(tester, 'Bold');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tapFormat(tester, 'Clear formatting');
      expect(notes.bodyText, 'Text');
      expect(notes.hasUnsavedChanges, false);
    },
  );

  testWidgets(
    'link dialog inserts display text and rejects unsupported URL schemes',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tapFormat(tester, 'Insert or edit link');
      await tester.enterText(
        find.widgetWithText(TextField, 'Display text'),
        'Visit the site',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'URL'),
        'javascript:alert(1)',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid website URL or mailto: email link.'),
        findsOneWidget,
      );
      expect(notes.bodyText, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'URL'),
        'https://example.com',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(notes.bodyText, 'Visit the site');
      notes.bodyController.updateSelection(
        const TextSelection.collapsed(offset: 5),
        ChangeSource.local,
      );
      await tapFormat(tester, 'Insert or edit link');
      expect(find.text('Edit link'), findsOneWidget);
      await tester.tap(find.text('Remove link'));
      await tester.pumpAndSettle();
      expect(notes.bodyText, 'Visit the site');
      expect(
        jsonEncode(notes.bodyController.document.toDelta().toJson()),
        isNot(contains('https://example.com')),
      );
    },
  );

  testWidgets('formatting dialogs stay behind the background lock screen', (
    tester,
  ) async {
    storage.appLock = true;
    storage.savedPin = '1234';
    await pumpApp(tester);
    await unlock(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    setBodyText(notes.bodyController, 'Private draft');
    notes.bodyController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 7),
      ChangeSource.local,
    );
    await tapFormat(tester, 'Highlight');
    expect(find.text('Highlight color'), findsOneWidget);
    await backgroundAndResume(tester);
    expect(find.text('Highlight color'), findsNothing);
    await unlock(tester);
    expect(find.text('Highlight color'), findsOneWidget);
    await tester.tap(find.byTooltip('Yellow'));
    await tester.pumpAndSettle();
    expect(notes.bodyText, 'Private draft');
    expect(
      notes.bodyController.document.toDelta().toJson().first['attributes'],
      containsPair('background', '#ffeb3b'),
    );
  });

  testWidgets(
    'rich-text editor fits a narrow phone with the keyboard visible',
    (tester) async {
      await pumpApp(tester);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(QuillEditor), findsOneWidget);
      await tapFormat(tester, 'Italic');
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('bottom-style-rail')))
            .dy,
        lessThanOrEqualTo(340),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filtered deletion removes the displayed note, then shows no matches',
    (tester) async {
      storage.notes = [
        makeNote('first', title: 'Keep me'),
        makeNote('second', title: 'Delete me'),
      ];
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField), 'Delete me');
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('note-second')));
      await tester.pump();
      await tester.tap(find.byTooltip('Delete note'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(storage.notes.single.id, 'first');
      expect(find.text('No notes found'), findsOneWidget);
      expect(find.text('Keep me'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);
    },
  );

  testWidgets('failed deletion leaves the selected note available for retry', (
    tester,
  ) async {
    storage.notes = [makeNote('keep')];
    await pumpApp(tester);
    storage.failWrites = true;
    await tester.longPress(find.byKey(const ValueKey('note-keep')));
    await tester.pump();
    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(storage.notes.single.id, 'keep');
    expect(find.byTooltip('Delete note'), findsOneWidget);
    storage.failWrites = false;
    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(storage.notes, isEmpty);
  });

  testWidgets('a search with no matches does not show every note', (
    tester,
  ) async {
    storage.notes = [makeNote('existing')];
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No notes found'), findsOneWidget);
    expect(find.text('existing'), findsNothing);
  });

  testWidgets(
    'system back saves a new draft and waits for persistence before leaving',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New title');
      await tester.tap(find.byType(QuillEditor));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'New body\n',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      storage.writeBarrier = Completer<void>();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NotePage), findsOneWidget);
      expect(notes.isSaving, true);
      storage.writeBarrier!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NotePage), findsNothing);
      expect(storage.notes.single.body, 'New body');
    },
  );

  testWidgets('save failure on exit keeps the editor and draft open', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Keep this draft');
    storage.failWrites = true;
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(NotePage), findsOneWidget);
    expect(notes.titleController.text, 'Keep this draft');
    expect(storage.notes, isEmpty);
    expect(
      find.text('Could not save changes. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'discarding cleared existing text does not silently overwrite the saved note',
    (tester) async {
      storage.notes = [makeNote('original', body: 'Original body')];
      await pumpApp(tester);
      await tester.tap(find.text('original'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      setBodyText(notes.bodyController, '');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(NotePage), findsNothing);
      expect(storage.notes.single.body, 'Original body');
    },
  );

  testWidgets('color-only edits prompt on system back and can be saved', (
    tester,
  ) async {
    storage.notes = [makeNote('colored')];
    await pumpApp(tester);
    await tester.tap(find.text('colored'));
    await tester.pumpAndSettle();
    notes.selectColor(1);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(storage.notes.single.color, 1);
    expect(find.byType(NotePage), findsNothing);
  });

  testWidgets('real app startup keeps notes hidden until PIN verification', (
    tester,
  ) async {
    storage.appLock = true;
    storage.savedPin = '1234';
    storage.notes = [makeNote('private')];
    await pumpApp(tester, realStartup: true);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Unlock JotIt'), findsOneWidget);
    expect(find.text('private'), findsNothing);
    await unlock(tester);
    expect(find.text('private'), findsOneWidget);
  });

  testWidgets(
    'background lock preserves editor and draft even after system back',
    (tester) async {
      storage.appLock = true;
      storage.savedPin = '1234';
      await pumpApp(tester);
      await unlock(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Unsaved private draft',
      );
      await backgroundAndResume(tester);
      expect(find.text('Unlock JotIt'), findsOneWidget);
      expect(find.byType(NotePage), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Unlock JotIt'), findsOneWidget);
      await unlock(tester);
      expect(find.byType(NotePage), findsOneWidget);
      expect(notes.titleController.text, 'Unsaved private draft');
      expect(find.text('Save changes?'), findsNothing);
    },
  );

  testWidgets('background lock also covers an open save dialog', (
    tester,
  ) async {
    storage.appLock = true;
    storage.savedPin = '1234';
    await pumpApp(tester);
    await unlock(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Private draft');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Save changes?'), findsOneWidget);
    await backgroundAndResume(tester);
    expect(find.text('Save changes?'), findsNothing);
    await unlock(tester);
    expect(find.text('Save changes?'), findsOneWidget);
  });

  testWidgets(
    'disabling App Lock requires the current PIN and clears biometrics',
    (tester) async {
      storage.appLock = true;
      storage.savedPin = '1234';
      storage.biometric = true;
      await pumpApp(tester);
      await unlock(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App Lock'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      expect(storage.appLock, true);
      expect(
        find.text('Incorrect PIN. App Lock is still enabled.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      expect(storage.appLock, false);
      expect(storage.biometric, false);
      expect(storage.savedPin, isEmpty);
      expect(auth!.isAppLock, false);
    },
  );

  testWidgets(
    'enabling App Lock requires matching PINs and persists the choice',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App Lock'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1234');
      await tester.enterText(find.byType(TextField).last, '5678');
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(storage.appLock, false);
      expect(find.text('PINs do not match.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '1234');
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(storage.appLock, true);
      expect(auth!.isAppLock, true);
      expect(auth!.isLocked, false);
      await backgroundAndResume(tester);
      expect(find.text('Unlock JotIt'), findsOneWidget);
    },
  );

  testWidgets(
    'backgrounding invalidates a pending request to disable App Lock',
    (tester) async {
      storage.appLock = true;
      storage.savedPin = '1234';
      await pumpApp(tester);
      await unlock(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('App Lock'));
      await tester.pumpAndSettle();
      final repository = auth!.authRepository as TestAuthRepository;
      repository.verification = Completer<bool>();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Disable'));
      await tester.pump();
      await backgroundAndResume(tester);
      repository.verification!.complete(true);
      await tester.pumpAndSettle();
      expect(storage.appLock, true);
      expect(auth!.isLocked, true);
      expect(find.text('Unlock JotIt'), findsOneWidget);
    },
  );

  testWidgets(
    'biometrics can be disabled when the device no longer supports them',
    (tester) async {
      storage.appLock = true;
      storage.savedPin = '1234';
      storage.biometric = true;
      biometrics.available = false;
      await pumpApp(tester);
      await unlock(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await auth!.saveBiometricEnabled(
        false,
        tester.element(find.byType(SettingsPage)),
      );
      await tester.pumpAndSettle();
      expect(auth!.isBiometricEnabled, false);
      expect(storage.biometric, false);
      expect(biometrics.calls, 0);
    },
  );
}
