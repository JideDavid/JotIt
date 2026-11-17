import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jot_it/core/services/google_auth_service.dart';
import 'package:jot_it/features/auth/repository/auth_repository.dart';

import 'support/fakes.dart';

class _User extends Fake implements User {}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);

  @override
  final User? user;
}

class _FirebaseAuth extends Fake implements FirebaseAuth {
  User? user;
  Object? error;
  int signInCalls = 0;
  int signOutCalls = 0;
  AuthCredential? credential;
  final changes = StreamController<User?>.broadcast();

  @override
  User? get currentUser => user;

  @override
  Stream<User?> userChanges() => changes.stream;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signInCalls++;
    if (error != null) throw error!;
    this.credential = credential;
    user = _User();
    changes.add(user);
    return _Credential(user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (error != null) throw error!;
    user = null;
    changes.add(null);
  }
}

class _Tokens extends Fake implements GoogleSignInAuthentication {
  @override
  String get accessToken => 'test-access-token';

  @override
  String get idToken => 'test-id-token';
}

class _GoogleAccount extends Fake implements GoogleSignInAccount {
  @override
  Future<GoogleSignInAuthentication> get authentication async => _Tokens();
}

class _GoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? account = _GoogleAccount();
  Object? signInError;
  Object? signOutError;
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (signInError != null) throw signInError!;
    return account;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    account = null;
    return null;
  }
}

void main() {
  late _FirebaseAuth firebase;
  late _GoogleSignIn google;
  late GoogleAuthService service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    firebase = _FirebaseAuth();
    google = _GoogleSignIn();
    service = GoogleAuthService(auth: firebase, googleSignIn: google);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await firebase.changes.close();
  });

  test('exchanges Google credentials for a Firebase session', () async {
    final user = await service.signInWithGoogle();
    expect(user, same(firebase.currentUser));
    expect(service.currentUser, same(user));
    expect(firebase.credential!.providerId, 'google.com');
    expect(service.isAvailable, true);
  });

  test('cancelled account picker never starts Firebase sign-in', () async {
    google.account = null;
    expect(await service.signInWithGoogle(), isNull);
    expect(firebase.signInCalls, 0);
  });

  test(
    'repository preserves SDK errors rather than treating them as cancellation',
    () async {
      final error = PlatformException(code: 'network_error');
      google.signInError = error;
      final repository = AuthRepository(
        authService: service,
        localStorageService: MemoryStorage(),
      );
      await expectLater(repository.signInWithGoogle(), throwsA(same(error)));
    },
  );

  test(
    'Firebase sign-out happens even if Google provider cleanup fails',
    () async {
      firebase.user = _User();
      google.signOutError = StateError('Provider cleanup failed');
      await service.signOut();
      expect(firebase.signOutCalls, 1);
      expect(google.signOutCalls, 1);
      expect(service.currentUser, isNull);
    },
  );

  test('Firebase sign-out failures are not swallowed', () async {
    final original = _User();
    firebase.user = original;
    final error = FirebaseAuthException(code: 'internal-error');
    firebase.error = error;
    await expectLater(service.signOut(), throwsA(same(error)));
    expect(service.currentUser, same(original));
    expect(google.signOutCalls, 0);
  });

  test(
    'missing configuration produces a local-only service, not a startup failure',
    () async {
      var serviceCreated = false;
      final unavailable = await GoogleAuthService.initialize(
        initializeFirebase: () async =>
            throw StateError('Missing configuration'),
        createService: () {
          serviceCreated = true;
          return service;
        },
      );
      expect(serviceCreated, false);
      expect(unavailable.isAvailable, false);
      expect(unavailable.currentUser, isNull);
      expect(await unavailable.userChanges.first, isNull);
      expect(unavailable.unavailableReason, contains('local notes'));
      await expectLater(unavailable.signInWithGoogle(), throwsStateError);
    },
  );

  test(
    'successful initialization supplies the configured account service',
    () async {
      final initialized = await GoogleAuthService.initialize(
        initializeFirebase: () async {},
        createService: () => service,
      );
      expect(initialized, same(service));
    },
  );

  test('unsupported platforms do not initialize Firebase', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    var initialized = false;
    final unavailable = await GoogleAuthService.initialize(
      initializeFirebase: () async => initialized = true,
    );
    expect(initialized, false);
    expect(unavailable.isAvailable, false);
    expect(unavailable.unavailableReason, contains('not supported'));
  });
}
