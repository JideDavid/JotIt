import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'support/fakes.dart';

void main() {
  late MemoryStorage storage;
  late TestAuthRepository repository;
  late TestBiometrics biometrics;
  late TestConnection connection;
  late AuthViewModel viewModel;
  late DateTime now;

  setUp(() {
    storage = MemoryStorage()
      ..appLock = true
      ..savedPin = '1234'
      ..biometric = true;
    repository = TestAuthRepository(storage);
    biometrics = TestBiometrics();
    connection = TestConnection();
    now = DateTime.utc(2026);
    viewModel = AuthViewModel(
      authRepository: repository,
      localBiometricService: biometrics,
      internetCheckerService: connection,
      now: () => now,
    );
  });
  tearDown(() {
    viewModel.dispose();
    connection.dispose();
  });

  Future<void> enterPin(String pin) async {
    for (final digit in pin.split('')) {
      await viewModel.unlockWithPin(digit);
    }
  }

  test('saved preferences are restored before the first lock screen', () {
    expect(viewModel.isAppLock, true);
    expect(viewModel.isLocked, true);
    expect(viewModel.isBiometricEnabled, true);
  });

  test('incorrect PIN retains the lock and clears input for retry', () async {
    await enterPin('0000');
    expect(viewModel.isLocked, true);
    expect(viewModel.pin, isEmpty);
    expect(viewModel.lockError, contains('Incorrect PIN'));
    await enterPin('1234');
    expect(viewModel.isLocked, false);
    expect(viewModel.lockError, isNull);
  });

  test(
    'fourth app PIN digit authenticates once and manual submit cannot duplicate it',
    () async {
      await enterPin('123');
      expect(repository.verificationCalls, 0);
      await viewModel.submitPin();
      expect(repository.verificationCalls, 0);
      repository.verification = Completer<bool>();
      final verifying = viewModel.unlockWithPin('4');
      expect(repository.verificationCalls, 1);
      await viewModel.submitPin();
      expect(repository.verificationCalls, 1);
      repository.verification!.complete(true);
      await verifying;
      expect(viewModel.isLocked, false);
    },
  );

  test('five incorrect attempts enforce a cooldown', () async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await enterPin('0000');
    }
    await enterPin('1234');
    expect(repository.verificationCalls, 5);
    expect(viewModel.isLocked, true);
    now = now.add(const Duration(seconds: 31));
    await enterPin('1234');
    expect(viewModel.isLocked, false);
  });

  test(
    'backgrounding relocks, while temporary inactive state does not',
    () async {
      await enterPin('1234');
      viewModel.handleLifecycle(AppLifecycleState.inactive);
      expect(viewModel.isLocked, false);
      viewModel.handleLifecycle(AppLifecycleState.hidden);
      expect(viewModel.isLocked, true);
      viewModel.handleLifecycle(AppLifecycleState.paused);
      viewModel.handleLifecycle(AppLifecycleState.resumed);
      expect(viewModel.isLocked, true);
    },
  );

  test(
    'an authentication started before backgrounding cannot unlock on return',
    () async {
      repository.verification = Completer<bool>();
      await enterPin('123');
      final authenticating = viewModel.unlockWithPin('4');
      viewModel.handleLifecycle(AppLifecycleState.paused);
      viewModel.handleLifecycle(AppLifecycleState.resumed);
      repository.verification!.complete(true);
      await authenticating;
      expect(viewModel.isLocked, true);
    },
  );

  test('biometric cancellation leaves PIN fallback available', () async {
    biometrics.succeeds = false;
    await viewModel.loginWithBiometrics();
    expect(viewModel.isLocked, true);
    expect(viewModel.isAuthenticating, false);
    await enterPin('1234');
    expect(viewModel.isLocked, false);
  });

  test('biometric success unlocks only the active lock session', () async {
    biometrics.authentication = Completer<bool>();
    final authenticating = viewModel.loginWithBiometrics();
    await Future<void>.delayed(Duration.zero);
    viewModel.handleLifecycle(AppLifecycleState.paused);
    viewModel.handleLifecycle(AppLifecycleState.resumed);
    biometrics.authentication!.complete(true);
    await authenticating;
    expect(viewModel.isLocked, true);
    biometrics.authentication = null;
    await viewModel.loginWithBiometrics();
    expect(viewModel.isLocked, false);
  });

  test('disabled biometrics cannot be invoked to bypass the PIN', () async {
    storage.biometric = false;
    viewModel.checkBiometricEnabled();
    await viewModel.loginWithBiometrics();
    expect(biometrics.calls, 0);
    expect(viewModel.isLocked, true);
  });

  test('backgrounding does not lock when App Lock is disabled', () {
    final unlockedStorage = MemoryStorage();
    final unlocked = AuthViewModel(
      authRepository: TestAuthRepository(unlockedStorage),
      localBiometricService: biometrics,
      internetCheckerService: connection,
    );
    addTearDown(unlocked.dispose);
    unlocked.handleLifecycle(AppLifecycleState.paused);
    unlocked.handleLifecycle(AppLifecycleState.resumed);
    expect(unlocked.isLocked, false);
    expect(unlocked.isBiometricEnabled, false);
  });
}
