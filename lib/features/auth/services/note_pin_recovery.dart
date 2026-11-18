import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/note_pin_record.dart';
import '../../../core/services/pin_hasher.dart';

class RecoveryAccount {
  const RecoveryAccount(this.uid, this.email, this.verified, this.idToken);
  final String uid, email, idToken;
  final bool verified;
}

class _RecoveryRejection extends FormatException {
  _RecoveryRejection(this.status, String message) : super(message);
  final int status;
}

class NotePinRecovery extends ChangeNotifier {
  NotePinRecovery({
    required this.box,
    required this.account,
    required this.currentUid,
    required this.confirmPin,
    required this.appCheckToken,
    required this.onReset,
    required this.allowed,
    http.Client? client,
    PinHasher? hasher,
    this.endpoint = const String.fromEnvironment('JOTIT_RECOVERY_URL'),
  }) : _client = client ?? http.Client(),
       _hasher = hasher ?? PinHasher();
  final Box<dynamic> box;
  final Future<RecoveryAccount?> Function() account;
  final String? Function() currentUid;
  final Future<bool> Function(String) confirmPin;
  final Future<String?> Function() appCheckToken;
  final VoidCallback onReset;
  final bool Function() allowed;
  final String endpoint;
  final http.Client _client;
  final PinHasher _hasher;
  bool _busy = false, _disposed = false;
  String? error, notice;
  Timer? _resendTimer;
  DateTime? _resendAt;
  bool get busy => _busy;
  bool get resendCoolingDown => _resendAt?.isAfter(DateTime.now()) ?? false;
  Map<String, dynamic> get _record {
    final raw = box.get('note_lock_pin');
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : {'hash': notePinHash(raw)};
  }

  Map<String, dynamic>? get _binding {
    final value = _record['recovery'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  bool get hasPin => notePinHash(box.get('note_lock_pin')).isNotEmpty;
  bool get linked => _binding?['enabled'] == true;
  bool get matchesAccount => linked && _binding?['uid'] == currentUid();
  bool matchesEmail(String email) =>
      matchesAccount && _binding?['email'] == email.toLowerCase();
  bool get pendingReset => _record['pendingReset'] is Map;
  String get maskedEmail {
    if (!matchesAccount) return 'Sign in to the enrolled account';
    final email = _binding?['email'] as String? ?? '';
    final at = email.indexOf('@');
    return at > 0 ? '${email[0]}•••${email.substring(at)}' : 'Linked account';
  }

  bool get configured {
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.path == '/v1/recovery';
  }

  String _random() {
    final random = Random.secure();
    return base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  Future<String> _fingerprint(String text) async => (await Sha256().hash(
    utf8.encode(text),
  )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  void _check(String uid) {
    if (_disposed || !allowed() || currentUid() != uid) {
      throw const FormatException(
        'Unlock the app and sign in to the enrolled account to continue.',
      );
    }
  }

  void _checkBinding(Map<String, dynamic> binding) {
    final stored = _binding;
    if (!hasPin ||
        stored == null ||
        stored['installationId'] != binding['installationId'] ||
        stored['deviceSecret'] != binding['deviceSecret'] ||
        stored['epoch'] != binding['epoch']) {
      throw const FormatException(
        'The local PIN or recovery enrollment changed. Reopen recovery to continue.',
      );
    }
  }

  Future<RecoveryAccount> _identity() async {
    if (!configured) {
      throw const FormatException(
        'Recovery is not configured in this build. No email has been sent.',
      );
    }
    final user = await account().timeout(const Duration(seconds: 15));
    if (user == null ||
        !user.verified ||
        user.email.isEmpty ||
        user.idToken.isEmpty) {
      throw const FormatException(
        'Sign in with a verified Google account to use recovery.',
      );
    }
    _check(user.uid);
    return user;
  }

  Map<String, dynamic> _credentials(Map<String, dynamic> binding) => {
    'installationId': binding['installationId'],
    'deviceSecret': binding['deviceSecret'],
    'epoch': binding['epoch'],
  };
  Future<Map<String, dynamic>> _post(
    String action,
    RecoveryAccount user,
    Map<String, dynamic> body,
  ) async {
    _check(user.uid);
    final attestation = await appCheckToken().timeout(
      const Duration(seconds: 15),
    );
    _check(user.uid);
    if (attestation == null || attestation.isEmpty) {
      throw const FormatException(
        'App verification is unavailable. Try again after reconnecting.',
      );
    }
    final response = await _client
        .post(
          Uri.parse('$endpoint/$action'),
          headers: {
            'Authorization': 'Bearer ${user.idToken}',
            'X-Firebase-AppCheck': attestation,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    _check(user.uid);
    if (response.statusCode != 200) {
      throw _RecoveryRejection(response.statusCode, switch (response
          .statusCode) {
        401 => 'Sign in again before using recovery.',
        403 =>
          'This account or installation does not match the recovery enrollment.',
        429 =>
          'Too many requests. Wait before trying again; recovery emails are limited to one per minute.',
        400 =>
          'This recovery link is invalid, expired or already used. Request a new link.',
        _ => 'Recovery is temporarily unavailable. No local PIN was changed.',
      });
    }
    if (response.bodyBytes.length > 4000) {
      throw const FormatException('Recovery returned an invalid response.');
    }
    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw const FormatException('Recovery returned an invalid response.');
    }
    return Map<String, dynamic>.from(json);
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy || _disposed) return false;
    _busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FormatException catch (e) {
      error = e.message.toString();
      return false;
    } catch (_) {
      error =
          'Could not finish recovery. Your saved PIN is unchanged; retry to finish an interrupted reset.';
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> enroll(String pin) => _run(() async {
    final user = await _identity();
    if (!hasPin || !await confirmPin(pin)) {
      throw const FormatException(
        'Verify your current shared note PIN before linking recovery.',
      );
    }
    _check(user.uid);
    final old = _binding;
    final originalHash = notePinHash(box.get('note_lock_pin'));
    if (old != null && old['uid'] != user.uid) {
      throw const FormatException(
        'Use the enrolled Google account. Changing recovery accounts is not available.',
      );
    }
    if (pendingReset) {
      throw const FormatException(
        'Finish the interrupted reset or request a new recovery link first.',
      );
    }
    final binding =
        old ??
        {
          'uid': user.uid,
          'installationId': _random(),
          'deviceSecret': _random(),
          'epoch': _random(),
        };
    binding['email'] = user.email.toLowerCase();
    binding['enabled'] = false;
    await box.put('note_lock_pin', {..._record, 'recovery': binding});
    final response = await _post('enroll', user, _credentials(binding));
    if (response['enabled'] != true || response['epoch'] != binding['epoch']) {
      throw const FormatException(
        'Recovery enrollment was not confirmed. Verify your PIN and try again.',
      );
    }
    _check(user.uid);
    _checkBinding(binding);
    if (notePinHash(box.get('note_lock_pin')) != originalHash) {
      throw const FormatException(
        'The note PIN changed. Verify it again to link recovery.',
      );
    }
    await box.put('note_lock_pin', {
      ..._record,
      'recovery': {...binding, 'enabled': true},
    });
    notice =
        'Recovery linked to your verified account on this installation. Keep access to that mailbox.';
  });
  Future<bool> disable(String pin) => _run(() async {
    final user = await _identity(), binding = _binding;
    if (!matchesAccount || binding == null || !await confirmPin(pin)) {
      throw const FormatException(
        'Verify the current note PIN using the enrolled account before unlinking recovery.',
      );
    }
    final response = await _post('disable', user, _credentials(binding));
    _checkBinding(binding);
    if (response['enabled'] != false) {
      throw const FormatException('Recovery could not be unlinked. Try again.');
    }
    await box.put('note_lock_pin', {
      ..._record,
      'recovery': {...binding, 'enabled': false},
      'pendingReset': null,
    });
    notice =
        'Recovery unlinked. Existing recovery links no longer work. Keep your note PIN safe.';
  });
  Future<bool> requestLink() => _run(() async {
    final user = await _identity(), binding = _binding;
    if (!matchesAccount || binding == null) {
      throw const FormatException(
        'Recovery was not enrolled for this account and installation.',
      );
    }
    final status = await _post('status', user, _credentials(binding));
    _checkBinding(binding);
    final epoch = status['epoch'];
    if (status['enabled'] != true ||
        epoch is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(epoch)) {
      throw const FormatException(
        'Recovery is unavailable for this installation.',
      );
    }
    final updated = {...binding, 'epoch': epoch};
    // Reconcile an interrupted server reset without changing the local PIN.
    await box.put('note_lock_pin', {
      ..._record,
      'recovery': updated,
      'pendingReset': null,
    });
    final response = await _post('request', user, _credentials(updated));
    if (response['sent'] != true) {
      throw const FormatException(
        'The recovery email was not confirmed. Try again later.',
      );
    }
    _resendAt = DateTime.now().add(const Duration(minutes: 1));
    _resendTimer?.cancel();
    _resendTimer = Timer(const Duration(minutes: 1), () {
      if (!_disposed) notifyListeners();
    });
    notice =
        'Recovery email accepted for delivery to $maskedEmail. The link expires in 15 minutes.';
  });
  Future<bool> reset(
    String link,
    String newPin,
    String confirmation,
  ) => _run(() async {
    if (!RegExp(r'^\d{4}$').hasMatch(newPin) || newPin != confirmation) {
      throw const FormatException(
        'Enter and confirm the same four-digit new note PIN.',
      );
    }
    final user = await _identity(), binding = _binding;
    if (!matchesAccount || binding == null) {
      throw const FormatException(
        'Recovery was not enrolled for this account and installation.',
      );
    }
    final uri = Uri.tryParse(link.trim()), base = Uri.parse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.origin != base.origin ||
        uri.path != '/recover' ||
        uri.hasQuery) {
      throw const FormatException(
        'Paste the full recovery link from your JotIt email.',
      );
    }
    final token = Uri.splitQueryString(uri.fragment)['token'];
    if (token == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const FormatException(
        'Paste the full recovery link from your JotIt email.',
      );
    }
    final tokenHash = await _fingerprint(token);
    final existing = _record['pendingReset'];
    Map<String, dynamic> pending;
    if (existing is Map) {
      pending = Map<String, dynamic>.from(existing);
      if (pending['tokenHash'] != tokenHash ||
          !await _hasher.verify(newPin, pending['hash'] as String)) {
        throw const FormatException(
          'Use the link and new PIN from the interrupted reset, or request a new recovery link.',
        );
      }
    } else {
      final encoded = await _hasher.hash(newPin);
      pending = {
        'hash': encoded,
        'previousHash': notePinHash(box.get('note_lock_pin')),
        'fingerprint': await _fingerprint(encoded),
        'newEpoch': _random(),
        'resetId': _random(),
        'tokenHash': tokenHash,
      };
      _check(user.uid);
      _checkBinding(binding);
      // Persist the chosen hash before consuming the one-use server token.
      await box.put('note_lock_pin', {..._record, 'pendingReset': pending});
    }
    late final Map<String, dynamic> receipt;
    try {
      receipt = await _post('redeem', user, {
        ..._credentials(binding),
        'token': token,
        'resetId': pending['resetId'],
        'newEpoch': pending['newEpoch'],
        'fingerprint': pending['fingerprint'],
      });
    } on _RecoveryRejection catch (rejection) {
      if (rejection.status == 400) {
        // Explicit rejection means this operation was not authorized. Unlike
        // a lost response, it must not prevent the user pasting a fresh link.
        _checkBinding(binding);
        await box.put('note_lock_pin', {..._record, 'pendingReset': null});
      }
      rethrow;
    }
    if (receipt['resetId'] != pending['resetId'] ||
        receipt['epoch'] != pending['newEpoch'] ||
        receipt['fingerprint'] != pending['fingerprint']) {
      throw const FormatException(
        'The recovery authorization does not match this reset. Your PIN is unchanged.',
      );
    }
    _check(user.uid);
    _checkBinding(binding);
    if (notePinHash(box.get('note_lock_pin')) != pending['previousHash']) {
      throw const FormatException(
        'The local note PIN changed. Reopen recovery before trying again.',
      );
    }
    await box.put('note_lock_pin', {
      'hash': pending['hash'],
      'recovery': {...binding, 'epoch': pending['newEpoch']},
      'pendingReset': null,
    });
    onReset();
    notice =
        'Shared note PIN updated. Protected notes remain locked; use your new PIN to open them.';
  });
  @override
  void dispose() {
    _disposed = true;
    _resendTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
