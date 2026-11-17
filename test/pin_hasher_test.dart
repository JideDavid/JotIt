import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/core/services/pin_hasher.dart';

// Independent Node.js PBKDF2-SHA256 vector: synthetic PIN 2468, salt 0..15,
// 600000 iterations, 32 output bytes. Also checked by the native Java test.
const digest = 'rDEMyFJ8bDpOINKiJG69d9WXZtrhxf6EPWXs9qfiDGU=';
const encoded = 'pbkdf2-sha256:600000:AAECAwQFBgcICQoLDA0ODw==:$digest';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jotit/pin_hash');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'Android dispatches verification to native crypto with the existing saved format',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'pbkdf2');
            expect(call.arguments['salt'], List.generate(16, (i) => i));
            final result = Uint8List.fromList(base64Decode(digest));
            if (call.arguments['pin'] != '2468') result[0] ^= 1;
            return result;
          });
      expect(await PinHasher().verify('2468', encoded), true);
      expect(await PinHasher().verify('8642', encoded), false);
      expect(calls, 2);
    },
  );
  test('native errors and malformed results never unlock', () async {
    for (final reply in [
      null,
      Uint8List(2),
      PlatformException(code: 'PIN_HASH_FAILED'),
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            if (reply is PlatformException) throw reply;
            return reply;
          });
      await expectLater(PinHasher().verify('2468', encoded), throwsA(anything));
    }
  });
  test(
    'portable fallback matches the independent legacy-compatible hash vector',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(await PinHasher().verify('2468', encoded), true);
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
  test(
    'invalid PINs and corrupt records are rejected before native work',
    () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            called = true;
            return Uint8List(32);
          });
      expect(await PinHasher().verify('bad', encoded), false);
      expect(
        await PinHasher().verify('2468', 'pbkdf2-sha256:600000:bad:bad'),
        false,
      );
      await expectLater(PinHasher().hash('123'), throwsArgumentError);
      expect(called, false);
    },
  );
}
