import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/internet_checker_service.dart';
import '../../../core/services/local_biometric_service.dart';
import '../../../shared/widgets/pin_auth_modal.dart';
import '../../../shared/widgets/z_snack_bar.dart';
import '../../notes/view/homepage.dart';
import '../repository/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final LocalBiometricService localBiometricService;
  final InternetCheckerService internetCheckerService;
  final DateTime Function() _now;
  late final StreamSubscription<bool> _connectionSubscription;
  late final StreamSubscription<User?> _accountSubscription;

  AuthViewModel({
    required this.authRepository,
    required this.localBiometricService,
    required this.internetCheckerService,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _isAppLock = authRepository.getAppLockChoice();
    _isLocked = _isAppLock;
    _isBiometricEnabled = _isAppLock && authRepository.getBiometricEnabled();
    _isConnected = internetCheckerService.isConnected;
    _currentUser = authRepository.getCurrentUser();
    _accountSubscription = authRepository.userChanges.listen(
      (user) {
        if (_disposed) return;
        _currentUser = user;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) return;
        _accountError =
            'Could not refresh your account. Your local notes are still available.';
        notifyListeners();
      },
    );
    _connectionSubscription = internetCheckerService.connectionStatusStream
        .listen((status) {
          _isConnected = status;
          notifyListeners();
        });
  }

  bool _isConnected = true;
  bool get isConnected => _isConnected;
  String _pin = '';
  String get pin => _pin;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _accountError;
  String? get accountError => _accountError;
  String? _accountNotice;
  String? get accountNotice => _accountNotice;
  bool get isAccountAvailable => authRepository.isAccountAvailable;
  String? get accountUnavailableReason =>
      authRepository.accountUnavailableReason;
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _isBiometricEnabled = false;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool _isAppLock = false;
  bool get isAppLock => _isAppLock;
  bool _isLocked = false;
  bool get isLocked => _isLocked;
  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;
  bool _changingLock = false;
  bool get changingLock => _changingLock;
  String? _lockError;
  String? get lockError => _lockError;
  bool _disposed = false;
  bool _inBackground = false;
  int _lockVersion = 0;
  int _failedAttempts = 0;
  DateTime? _retryAfter;

  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _inBackground = true;
      lockApp();
    } else if (state == AppLifecycleState.resumed) {
      _inBackground = false;
    }
  }

  void lockApp() {
    if (_disposed || !_isAppLock) return;
    _lockVersion++;
    _isLocked = true;
    _pin = '';
    notifyListeners();
  }

  void _unlock(int version) {
    if (_inBackground || version != _lockVersion || !_isAppLock) return;
    _isLocked = false;
    _pin = '';
    _lockError = null;
    _failedAttempts = 0;
    _retryAfter = null;
  }

  Future<void> unlockWithPin(String input) async {
    if (!_isLocked || _isAuthenticating || !RegExp(r'^\d$').hasMatch(input)) {
      return;
    }
    if (_retryAfter != null && _now().isBefore(_retryAfter!)) {
      _lockError = 'Too many attempts. Try again in 30 seconds.';
      notifyListeners();
      return;
    }
    _lockError = null;
    _pin += input;
    notifyListeners();
    if (_pin.length != 4) return;
    await submitPin();
  }

  Future<void> submitPin() async {
    if (!_isLocked || _isAuthenticating) return;
    if (_pin.length != 4) {
      _lockError = 'Enter your four-digit app PIN.';
      notifyListeners();
      return;
    }
    if (_retryAfter != null && _now().isBefore(_retryAfter!)) {
      _lockError = 'Too many attempts. Try again in 30 seconds.';
      notifyListeners();
      return;
    }
    final enteredPin = _pin;
    final version = _lockVersion;
    _isAuthenticating = true;
    notifyListeners();
    try {
      final authenticated = await authenticatePin(enteredPin);
      if (_disposed) return;
      if (authenticated) {
        _unlock(version);
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _retryAfter = _now().add(const Duration(seconds: 30));
          _failedAttempts = 0;
          _lockError = 'Too many attempts. Try again in 30 seconds.';
        } else {
          _lockError = 'Incorrect PIN. Please try again.';
        }
      }
    } catch (_) {
      _lockError = 'Could not verify PIN. Please try again.';
    } finally {
      _pin = '';
      _isAuthenticating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> authenticatePin(String pin) =>
      authRepository.verifyAppLockPin(pin);

  void backspacePin() {
    if (_pin.isEmpty || _isAuthenticating) return;
    _pin = _pin.substring(0, _pin.length - 1);
    notifyListeners();
  }

  void routeToHomepage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Homepage()),
    );
  }

  Future<void> loginWithGoogle() async {
    if (_disposed || _isLoading || _currentUser != null) return;
    if (!isAccountAvailable) {
      _accountError = accountUnavailableReason;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _accountError = null;
    _accountNotice = null;
    notifyListeners();
    try {
      final user = await authRepository.signInWithGoogle();
      if (_disposed) return;
      _currentUser = user;
      if (user == null) {
        _accountNotice =
            'Sign-in cancelled. Your local notes are still available.';
      }
    } catch (error) {
      if (_disposed) return;
      final code = switch (error) {
        FirebaseAuthException() => error.code,
        PlatformException() => error.code,
        _ => '',
      };
      if (const {
        'sign_in_canceled',
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-canceled',
      }.contains(code)) {
        _accountNotice =
            'Sign-in cancelled. Your local notes are still available.';
      } else {
        _accountError = switch (code) {
          'network-request-failed' || 'network_error' =>
            'Could not connect. Check your internet connection and try again. Your local notes are still available.',
          'too-many-requests' =>
            'Too many sign-in attempts. Please wait and try again.',
          'user-disabled' =>
            'This account is disabled. Try another Google account or continue with local notes.',
          'popup-blocked' =>
            'Allow the sign-in popup in your browser, then try again.',
          'account-exists-with-different-credential' =>
            'This email already uses another sign-in method. No accounts have been merged. Continue with local notes for now.',
          'operation-not-allowed' ||
          'invalid-api-key' ||
          'app-not-authorized' ||
          'unauthorized-domain' ||
          'sign_in_failed' =>
            'Google sign-in needs app configuration. Your local notes are still available.',
          _ =>
            'Could not sign in. Please try again or continue with local notes.',
        };
      }
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> loginWithBiometrics() async {
    if (!_isLocked || !_isBiometricEnabled || _isAuthenticating) return;
    final version = _lockVersion;
    _isAuthenticating = true;
    _lockError = null;
    notifyListeners();
    try {
      final authenticated = await authenticateWithBiometric();
      if (_disposed) return;
      if (authenticated) {
        _unlock(version);
      } else {
        _lockError = 'Biometric unlock failed. Use your PIN or try again.';
      }
    } finally {
      _isAuthenticating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> authenticateWithBiometric() async {
    if (!await localBiometricService.isBiometricAvailable()) return false;
    return localBiometricService.authenticate();
  }

  Future<void> logout() async {
    if (_disposed || _isLoading || _currentUser == null) return;
    _isLoading = true;
    _accountError = null;
    _accountNotice = null;
    notifyListeners();
    try {
      await authRepository.signOut();
      if (_disposed) return;
      _currentUser = null;
      _accountNotice =
          'Signed out. Notes, attachments and PIN settings remain on this device.';
    } catch (_) {
      if (_disposed) return;
      _accountError = 'Could not sign out. Please try again.';
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void getCurrentUser() {
    _currentUser = authRepository.getCurrentUser();
    notifyListeners();
  }

  void checkBiometricEnabled() {
    _isBiometricEnabled = _isAppLock && authRepository.getBiometricEnabled();
    notifyListeners();
  }

  Future<void> saveBiometricEnabled(bool enabled, BuildContext context) async {
    if (_changingLock || !_isAppLock) return;
    final version = _lockVersion;
    _changingLock = true;
    notifyListeners();
    try {
      if (enabled && !await authenticateWithBiometric()) {
        if (context.mounted) {
          ZSnackBar().error(context, 'Biometric authentication unavailable');
        }
        return;
      }
      if (_disposed || _isLocked || _inBackground || version != _lockVersion) {
        return;
      }
      await authRepository.saveBiometricEnabled(enabled);
      _isBiometricEnabled = enabled;
    } catch (_) {
      if (context.mounted) {
        ZSnackBar().error(context, 'Could not update biometrics');
      }
    } finally {
      _changingLock = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> toggleAppLockChoice(BuildContext context) async {
    if (_changingLock || _isLocked) return;
    final version = _lockVersion;
    _changingLock = true;
    notifyListeners();
    try {
      if (_isAppLock) {
        if (!await PinInputModal.removePin(context)) return;
        if (_disposed ||
            _isLocked ||
            _inBackground ||
            version != _lockVersion) {
          return;
        }
        await authRepository.saveAppLockChoice(false);
        _isAppLock = false;
        _isBiometricEnabled = false;
        _isLocked = false;
      } else {
        final pin = await PinInputModal.setPin(context);
        if (pin == null || _disposed) return;
        await authRepository.saveAppLockPin(pin);
        await authRepository.saveAppLockChoice(true);
        _isAppLock = true;
        if (_inBackground) lockApp();
      }
    } catch (_) {
      if (context.mounted) {
        ZSnackBar().error(context, 'Could not update App Lock');
      }
    } finally {
      _changingLock = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionSubscription.cancel();
    _accountSubscription.cancel();
    super.dispose();
  }
}
