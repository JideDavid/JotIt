import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PinHasher {
  static const _prefix = 'pbkdf2-sha256:600000';

  Future<String> hash(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain four digits.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final digest = await _derive(pin, salt);
    return '$_prefix:${base64Encode(salt)}:${base64Encode(digest)}';
  }

  Future<bool> verify(String pin, String encoded) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) return false;
    final parts = encoded.split(':');
    if (parts.length != 4 || !encoded.startsWith('$_prefix:')) return false;
    try {
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      if (salt.length != 16 || expected.length != 32) return false;
      final actual = await _derive(pin, salt);
      var difference = 0;
      for (var index = 0; index < expected.length; index++) {
        difference |= expected[index] ^ actual[index];
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  Future<List<int>> _derive(String pin, List<int> salt) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final bytes = await const MethodChannel('jotit/pin_hash')
            .invokeMethod<Uint8List>('pbkdf2', {
              'pin': pin,
              'salt': Uint8List.fromList(salt),
            });
        if (bytes == null || bytes.length != 32) {
          throw StateError('Native PIN derivation returned an invalid result.');
        }
        return bytes;
      } on MissingPluginException {
        // Older/test hosts retain the compatible isolate implementation.
      } on PlatformException catch (error) {
        if (error.code != 'PIN_HASH_UNAVAILABLE') rethrow;
      }
    }
    return compute(_derivePin, (pin, salt));
  }
}

Future<List<int>> _derivePin((String, List<int>) input) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );
  final key = await algorithm.deriveKeyFromPassword(
    password: input.$1,
    nonce: input.$2,
  );
  return key.extractBytes();
}
