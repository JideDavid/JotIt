import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/core/theme/appearance_view_model.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/auth/view/app_lock_gate.dart';
import 'package:jot_it/features/auth/view/login_page.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/homepage.dart';
import 'package:jot_it/views/settings_page.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

class AccountUser extends Fake implements User {
  @override
  String get uid => 'test-account';

  @override
  String get email => 'writer@example.invalid';

  @override
  bool get emailVerified => true;
}

void main() {
  late MemoryStorage storage;
  late TestAuthRepository repository;
  late TestConnection connection;
  late AuthViewModel auth;
  late StreamController<User?> changes;

  AuthViewModel createAuth() => AuthViewModel(
    authRepository: repository,
    localBiometricService: TestBiometrics(),
    internetCheckerService: connection,
  );

  setUp(() {
    storage = MemoryStorage()
      ..notes = [makeNote('local', body: 'Local content', isLocked: true)]
      ..notePin = '2468';
    repository = TestAuthRepository(storage);
    connection = TestConnection();
    changes = StreamController<User?>.broadcast();
    repository.accountChanges = changes.stream;
    auth = createAuth();
  });

  tearDown(() async {
    auth.dispose();
    connection.dispose();
    await changes.close();
  });

  test('restores the SDK session immediately without a sign-in request', () {
    auth.dispose();
    repository.user = AccountUser();
    auth = createAuth();
    expect(auth.currentUser, same(repository.user));
    expect(repository.signInCalls, 0);
  });

  test('SDK account changes and sign-out update the session', () async {
    final user = AccountUser();
    changes.add(user);
    await Future<void>.delayed(Duration.zero);
    expect(auth.currentUser, same(user));
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(auth.currentUser, isNull);
  });

  test('an existing session and local data remain usable offline', () {
    auth.dispose();
    connection.connected = false;
    repository.user = AccountUser();
    auth = createAuth();
    expect(auth.isConnected, false);
    expect(auth.currentUser, same(repository.user));
    expect(repository.signInCalls, 0);
    expect(storage.notes.single.body, 'Local content');
    expect(storage.notePin, '2468');
  });

  test(
    'account stream errors are contained without losing local notes',
    () async {
      changes.addError(StateError('Private SDK diagnostics'));
      await Future<void>.delayed(Duration.zero);
      expect(auth.accountError, contains('refresh'));
      expect(auth.accountError, isNot(contains('Private SDK')));
      expect(storage.notes.single.body, 'Local content');
    },
  );

  test('duplicate sign-in and sign-out cannot overlap', () async {
    repository.signInResult = Completer<User?>();
    final signingIn = auth.loginWithGoogle();
    expect(auth.isLoading, true);
    await auth.loginWithGoogle();
    await auth.logout();
    expect(repository.signInCalls, 1);
    expect(repository.signOutCalls, 0);
    repository.signInResult!.complete(AccountUser());
    await signingIn;
    expect(auth.currentUser, isNotNull);
    expect(auth.isLoading, false);
    await auth.loginWithGoogle();
    expect(repository.signInCalls, 1);
  });

  test('cancelled sign-in gives a neutral notice and can be retried', () async {
    await auth.loginWithGoogle();
    expect(auth.accountError, isNull);
    expect(auth.accountNotice, contains('cancelled'));
    repository.user = AccountUser();
    await auth.loginWithGoogle();
    expect(auth.accountNotice, isNull);
    expect(auth.currentUser, same(repository.user));
  });

  for (final error in [
    FirebaseAuthException(code: 'popup-closed-by-user'),
    PlatformException(code: 'sign_in_canceled'),
  ]) {
    test('SDK cancellation is not reported as an error: $error', () async {
      repository.signInError = error;
      await auth.loginWithGoogle();
      expect(auth.accountNotice, contains('cancelled'));
      expect(auth.accountError, isNull);
      expect(auth.isLoading, false);
    });
  }

  test('network failures are retryable without losing local access', () async {
    repository.signInError = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'Sensitive internal diagnostics',
    );
    await auth.loginWithGoogle();
    expect(auth.accountError, contains('internet connection'));
    expect(auth.accountError, isNot(contains('Sensitive')));
    expect(storage.saveCalls, 0);
    expect(storage.notes, hasLength(1));
    repository.signInError = null;
    repository.user = AccountUser();
    await auth.loginWithGoogle();
    expect(auth.currentUser, isNotNull);
    expect(auth.accountError, isNull);
  });

  test('an unconfigured account cannot start the SDK flow', () async {
    repository.accountAvailable = false;
    repository.unavailableReason = 'Configuration is missing.';
    await auth.loginWithGoogle();
    expect(repository.signInCalls, 0);
    expect(auth.accountError, 'Configuration is missing.');
    expect(auth.isLoading, false);
  });

  test('sign-out preserves notes, PINs and appearance', () async {
    storage.appLock = true;
    storage.savedPin = '1234';
    storage.biometric = true;
    storage.appearance = 'dark';
    repository.user = AccountUser();
    auth.getCurrentUser();
    repository.signOutResult = Completer<void>();
    final signingOut = auth.logout();
    await auth.logout();
    await auth.loginWithGoogle();
    expect(repository.signOutCalls, 1);
    expect(repository.signInCalls, 0);
    repository.signOutResult!.complete();
    await signingOut;
    expect(auth.currentUser, isNull);
    expect(auth.accountNotice, contains('Signed out'));
    expect(storage.notes.single.body, 'Local content');
    expect(storage.notePin, '2468');
    expect(storage.appLock, true);
    expect(storage.savedPin, '1234');
    expect(storage.biometric, true);
    expect(storage.appearance, 'dark');
    expect(storage.saveCalls, 0);
  });

  test('failed sign-out retains the account and allows retry', () async {
    repository.user = AccountUser();
    auth.getCurrentUser();
    repository.signOutError = StateError('SDK failure');
    await auth.logout();
    expect(auth.currentUser, same(repository.user));
    expect(auth.accountError, contains('Could not sign out'));
    expect(auth.isLoading, false);
    repository.signOutError = null;
    await auth.logout();
    expect(auth.currentUser, isNull);
    expect(auth.accountError, isNull);
  });

  test('a sign-in result never unlocks App Lock', () async {
    auth.dispose();
    storage.appLock = true;
    storage.savedPin = '1234';
    auth = createAuth();
    repository.signInResult = Completer<User?>();
    final signingIn = auth.loginWithGoogle();
    auth.handleLifecycle(AppLifecycleState.paused);
    auth.handleLifecycle(AppLifecycleState.resumed);
    repository.signInResult!.complete(AccountUser());
    await signingIn;
    expect(auth.isLocked, true);
    expect(storage.savedPin, '1234');
    expect(storage.notePin, '2468');
  });

  test('pending results and stream events are safe after disposal', () async {
    repository.signInResult = Completer<User?>();
    final signingIn = auth.loginWithGoogle();
    auth.dispose();
    repository.signInResult!.complete(AccountUser());
    await signingIn;
    changes.add(AccountUser());
    await Future<void>.delayed(Duration.zero);
    auth = createAuth();
  });

  Future<void> pumpAccount(
    WidgetTester tester, {
    bool library = false,
    ThemeMode mode = ThemeMode.light,
  }) async {
    final appearance = AppearanceViewModel(storage);
    final notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: storage),
    );
    addTearDown(appearance.dispose);
    addTearDown(notes.dispose);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: appearance),
          ChangeNotifierProvider.value(value: notes),
        ],
        child: MaterialApp(
          theme: LSTAppTheme.lightTheme,
          darkTheme: LSTAppTheme.darkTheme,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: AppLockGate(
            child: library ? const Homepage() : const LoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'connected account and sign-out confirmation fit ${mode.name}',
      (tester) async {
        repository.user = AccountUser();
        auth.getCurrentUser();
        await pumpAccount(tester, mode: mode);
        expect(find.textContaining('writer@example.invalid'), findsOneWidget);
        expect(find.text('Google email verified'), findsOneWidget);
        await tester.ensureVisible(find.text('Sign out'));
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(find.text('Sign out of JotIt?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(repository.signOutCalls, 0);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
        await tester.pumpAndSettle();
        expect(repository.signOutCalls, 1);
        expect(find.textContaining('Signed out.'), findsOneWidget);
        expect(storage.notes, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('local navigation returns to the existing library', (
    tester,
  ) async {
    await pumpAccount(tester, library: true);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Account'), 200);
    await tester.ensureVisible(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with local notes'));
    await tester.tap(find.text('Continue with local notes'));
    await tester.pumpAndSettle();
    expect(find.byType(Homepage), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('leaving a pending sign-in never redirects on completion', (
    tester,
  ) async {
    repository.signInResult = Completer<User?>();
    await pumpAccount(tester);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(auth.isLoading, true);
    await tester.ensureVisible(find.text('Continue with local notes'));
    await tester.tap(find.text('Continue with local notes'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Homepage), findsOneWidget);
    repository.signInResult!.complete(AccountUser());
    await tester.pumpAndSettle();
    expect(find.byType(Homepage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(storage.notes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing configuration keeps local access visible', (
    tester,
  ) async {
    repository.accountAvailable = false;
    repository.unavailableReason = 'Account setup is missing.';
    await pumpAccount(tester);
    expect(find.text('Account setup is missing.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue with Google'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Continue with local notes'));
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Continue with local notes'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
