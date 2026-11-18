import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:jot_it/core/theme/appearance_view_model.dart';
import 'package:jot_it/core/theme/quiet_palette.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/note_page.dart';
import 'package:jot_it/main.dart';
import 'support/fakes.dart';

void main() {
  test(
    'fresh installs follow System; existing data migrates to Dark',
    () async {
      final storage = MemoryStorage();
      final fresh = AppearanceViewModel(storage);
      expect(fresh.mode, ThemeMode.system);
      await fresh.initialize();
      expect(storage.appearance, 'system');
      fresh.dispose();
      storage.appearance = null;
      storage.notes = [makeNote('old')];
      final migrated = AppearanceViewModel(storage);
      expect(migrated.mode, ThemeMode.dark);
      await migrated.initialize();
      migrated.dispose();
      final reopened = AppearanceViewModel(storage);
      expect(reopened.mode, ThemeMode.dark);
      reopened.dispose();
    },
  );

  test(
    'appearance writes complete before applying and failed writes can retry',
    () async {
      final storage = MemoryStorage()..appearance = 'dark';
      final appearance = AppearanceViewModel(storage);
      addTearDown(appearance.dispose);
      storage.writeBarrier = Completer<void>();
      final saving = appearance.setMode(ThemeMode.light);
      expect(appearance.saving, true);
      expect(appearance.mode, ThemeMode.dark);
      expect(await appearance.setMode(ThemeMode.system), false);
      storage.writeBarrier!.complete();
      expect(await saving, true);
      expect(appearance.mode, ThemeMode.light);
      storage.failWrites = true;
      expect(await appearance.setMode(ThemeMode.dark), false);
      expect(appearance.mode, ThemeMode.light);
      expect(storage.appearance, 'light');
      expect(appearance.error, isNotNull);
      storage.failWrites = false;
      expect(await appearance.setMode(ThemeMode.dark), true);
      expect(appearance.error, isNull);
    },
  );

  test('startup preference failure does not prevent app startup', () async {
    final storage = MemoryStorage()..failWrites = true;
    final appearance = AppearanceViewModel(storage);
    await appearance.initialize();
    expect(appearance.mode, ThemeMode.system);
    expect(appearance.error, isNotNull);
    appearance.dispose();
  });

  double contrast(Color foreground, Color background) {
    final luminances = [
      foreground.computeLuminance(),
      background.computeLuminance(),
    ]..sort();
    return (luminances.last + 0.05) / (luminances.first + 0.05);
  }

  test(
    'Quiet paper text and all note-card palettes maintain readable contrast',
    () {
      for (final theme in [LSTAppTheme.lightTheme, LSTAppTheme.darkTheme]) {
        final scheme = theme.colorScheme;
        final palette = theme.extension<QuietPalette>()!;
        for (final background in [
          ...palette.noteSurfaces,
          theme.scaffoldBackgroundColor,
          scheme.surfaceContainer,
        ]) {
          expect(
            contrast(scheme.onSurface, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(scheme.onSurfaceVariant, background),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrast(LSTAppTheme.amberInk, LSTAppTheme.amber),
          greaterThan(4.5),
        );
        expect(theme.textTheme.bodyMedium!.color!.a, 1);
      }
    },
  );

  group('themed app', () {
    late MemoryStorage storage;
    late AppearanceViewModel appearance;
    late NoteViewModel notes;
    late AuthViewModel auth;
    late TestConnection connection;

    setUp(() {
      storage = MemoryStorage()..appearance = 'light';
      storage.notes = [makeNote('sample', body: 'Saved text')];
      appearance = AppearanceViewModel(storage);
      notes = NoteViewModel(notesRepo: NotesRepo(localStorageService: storage));
      connection = TestConnection();
      auth = AuthViewModel(
        authRepository: TestAuthRepository(storage),
        localBiometricService: TestBiometrics(),
        internetCheckerService: connection,
      );
    });
    tearDown(() {
      appearance.dispose();
      notes.dispose();
      auth.dispose();
      connection.dispose();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 850);
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
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Brightness brightness(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).last)).brightness;

    testWidgets('Settings applies and persists Light, Dark and System', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(brightness(tester), Brightness.light);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('appearance-dark')));
      await tester.pumpAndSettle();
      expect(storage.appearance, 'dark');
      expect(brightness(tester), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      await tester.tap(find.byKey(const ValueKey('appearance-system')));
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      await tester.tap(find.byKey(const ValueKey('appearance-light')));
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.light);
      expect(storage.appearance, 'light');
    });

    testWidgets(
      'theme switches retain unsaved rich text, selection and paper',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(find.text('sample'));
        await tester.pumpAndSettle();
        setBodyText(notes.bodyController, 'Unsaved styled text');
        notes.bodyController.formatText(0, 7, const ColorAttribute('#ef5350'));
        notes.bodyController.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 7),
          ChangeSource.local,
        );
        final delta = notes.bodyController.document.toDelta().toJson();
        final paper = notes.paper;
        await appearance.setMode(ThemeMode.dark);
        await tester.pumpAndSettle();
        expect(find.byType(NotePage), findsOneWidget);
        expect(notes.bodyController.document.toDelta().toJson(), delta);
        expect(
          notes.bodyController.selection,
          const TextSelection(baseOffset: 0, extentOffset: 7),
        );
        expect(notes.paper, paper);
        expect(notes.hasUnsavedChanges, true);
        expect(storage.notes.single.body, 'Saved text');
        expect(
          find.text('Unsaved changes · save when you’re ready'),
          findsOneWidget,
        );
      },
    );

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'library, settings and editor reflow at 320px with large text in ${mode.name}',
        (tester) async {
          await appearance.setMode(mode);
          await pumpApp(tester);
          tester.view.physicalSize = const Size(320, 640);
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('note-sample')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('sample'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('changing appearance cannot bypass a shared note lock', (
      tester,
    ) async {
      storage.notePin = '1234';
      storage.notes = [
        makeNote('private', body: 'Hidden text', isLocked: true),
      ];
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('note-private')));
      await tester.pumpAndSettle();
      await appearance.setMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(notes.needsNoteUnlock, true);
      expect(find.byType(NotePage), findsNothing);
      expect(find.text('Hidden text'), findsNothing);
      expect(find.widgetWithText(TextField, 'Note PIN'), findsOneWidget);
      expect(find.text('This note is locked'), findsOneWidget);
    });
  });
}
