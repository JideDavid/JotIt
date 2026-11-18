import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jot_it/core/services/note_pin_record.dart';
import 'package:jot_it/core/services/pin_hasher.dart';
import 'package:jot_it/features/auth/services/note_pin_recovery.dart';
import 'package:jot_it/features/auth/view/note_pin_recovery_page.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';
import 'support/fakes.dart';

class RecoveryUser extends Fake implements User {
  @override
  String get uid => 'owner';
  @override
  String get email => 'owner@example.test';
  @override
  bool get emailVerified => true;
}

class RecoveryBox extends Fake implements Box<dynamic> {
  final entries = <dynamic, dynamic>{
    'note_lock_pin': 'old-hash',
    'unrelated': 'keep',
  };
  bool failNextPut = false;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      entries[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failNextPut) {
      failNextPut = false;
      throw StateError('Disk unavailable');
    }
    entries[key] = jsonDecode(jsonEncode(value));
  }
}

class RecoveryHasher extends PinHasher {
  int hashes = 0;
  @override
  Future<String> hash(String pin) async {
    hashes++;
    return 'test-hash-$pin';
  }

  @override
  Future<bool> verify(String pin, String encoded) async =>
      encoded == 'test-hash-$pin';
}

class Fixture {
  final box = RecoveryBox(), hasher = RecoveryHasher();
  String uid = 'owner', email = 'owner@example.test';
  bool validPin = true,
      verified = true,
      unlocked = true,
      failRedeem = false,
      invalidLink = false,
      badReceipt = false,
      failWrite = false,
      switchAccount = false;
  int resets = 0, pinChecks = 0;
  final requests = <Map<String, dynamic>>[];
  late final NotePinRecovery recovery = NotePinRecovery(
    box: box,
    account: () async =>
        RecoveryAccount(uid, email, verified, 'firebase-token'),
    currentUid: () => uid,
    confirmPin: (_) async {
      pinChecks++;
      return validPin;
    },
    appCheckToken: () async => 'attestation',
    allowed: () => unlocked,
    onReset: () => resets++,
    hasher: hasher,
    endpoint: 'https://recovery.example.test/v1/recovery',
    client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer firebase-token');
      expect(request.headers['X-Firebase-AppCheck'], 'attestation');
      final body = Map<String, dynamic>.from(jsonDecode(request.body));
      requests.add({'action': request.url.pathSegments.last, ...body});
      switch (request.url.pathSegments.last) {
        case 'enroll':
          return http.Response(
            jsonEncode({'enabled': true, 'epoch': body['epoch']}),
            200,
          );
        case 'status':
          return http.Response(
            jsonEncode({'enabled': true, 'epoch': body['epoch']}),
            200,
          );
        case 'request':
          return http.Response('{"sent":true}', 200);
        case 'disable':
          return http.Response('{"enabled":false}', 200);
        case 'redeem':
          if (invalidLink) return http.Response('{}', 400);
          if (failRedeem) return http.Response('{}', 503);
          if (failWrite) box.failNextPut = true;
          if (switchAccount) uid = 'other';
          return http.Response(
            jsonEncode({
              'resetId': badReceipt ? 'wrong' : body['resetId'],
              'epoch': body['newEpoch'],
              'fingerprint': body['fingerprint'],
            }),
            200,
          );
      }
      return http.Response('{}', 404);
    }),
  );
  String get link =>
      'https://recovery.example.test/recover#token=${List.filled(43, 'A').join()}';
}

void main() {
  test(
    'email changes require verifying the note PIN again before relinking',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      await f.recovery.enroll('1234');
      f.email = 'new-owner@example.test';
      expect(f.recovery.matchesEmail(f.email), false);
      f.validPin = false;
      expect(await f.recovery.enroll('wrong'), false);
      expect(f.recovery.matchesEmail(f.email), false);
      f.validPin = true;
      expect(await f.recovery.enroll('1234'), true);
      expect(f.recovery.matchesEmail(f.email), true);
      expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
    },
  );
  test('a rejected expired link does not block pasting a fresh link', () async {
    final f = Fixture();
    addTearDown(f.recovery.dispose);
    await f.recovery.enroll('1234');
    f.invalidLink = true;
    expect(await f.recovery.reset(f.link, '2468', '2468'), false);
    expect(f.recovery.pendingReset, false);
    expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
    f.invalidLink = false;
    expect(
      await f.recovery.reset(
        f.link.replaceFirst('token=A', 'token=B'),
        '8642',
        '8642',
      ),
      true,
    );
    expect(notePinHash(f.box.get('note_lock_pin')), 'test-hash-8642');
  });
  testWidgets(
    'recovery enrollment and reset fit a narrow keyboard-open phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final f = Fixture(), connection = TestConnection();
      final repository = TestAuthRepository(MemoryStorage())
        ..user = RecoveryUser();
      final auth = AuthViewModel(
        authRepository: repository,
        localBiometricService: TestBiometrics(),
        internetCheckerService: connection,
      );
      addTearDown(f.recovery.dispose);
      addTearDown(auth.dispose);
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(home: NotePinRecoveryPage(recovery: f.recovery)),
        ),
      );
      final current = find.widgetWithText(TextField, 'Current shared note PIN');
      await tester.scrollUntilVisible(
        current,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(current, '1234');
      await tester.ensureVisible(find.text('Link recovery'));
      await tester.tap(find.text('Link recovery'));
      await tester.pumpAndSettle();
      expect(f.recovery.linked, true);
      expect(tester.takeException(), isNull);
      for (final field in [
        ('Recovery link from your email', f.link),
        ('New shared note PIN', '2468'),
        ('Confirm new note PIN', '2468'),
      ]) {
        final finder = find.widgetWithText(TextField, field.$1);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, field.$2);
      }
      await tester.ensureVisible(find.text('Reset note PIN'));
      await tester.tap(find.text('Reset note PIN'));
      await tester.pumpAndSettle();
      expect(f.resets, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'unlinking requires the existing note PIN and preserves the PIN record',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      await f.recovery.enroll('1234');
      f.validPin = false;
      expect(await f.recovery.disable('wrong'), false);
      expect(f.recovery.linked, true);
      f.validPin = true;
      expect(await f.recovery.disable('1234'), true);
      expect(f.recovery.linked, false);
      expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
    },
  );
  test(
    'enrollment requires the current note PIN and verified account',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      f.verified = false;
      expect(await f.recovery.enroll('1234'), false);
      expect(f.pinChecks, 0);
      f.verified = true;
      f.validPin = false;
      expect(await f.recovery.enroll('1234'), false);
      expect(f.requests, isEmpty);
      f.validPin = true;
      expect(await f.recovery.enroll('1234'), true);
      expect(f.recovery.linked, true);
      expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
      expect(f.recovery.maskedEmail, 'o•••@example.test');
    },
  );
  test(
    'unconfigured recovery cannot send mail or write local enrollment',
    () async {
      final box = RecoveryBox();
      var called = false;
      final r = NotePinRecovery(
        box: box,
        currentUid: () => null,
        account: () async {
          called = true;
          return null;
        },
        confirmPin: (_) async => true,
        appCheckToken: () async => null,
        onReset: () {},
        allowed: () => true,
        endpoint: '',
      );
      addTearDown(r.dispose);
      expect(await r.enroll('1234'), false);
      expect(called, false);
      expect(box.get('note_lock_pin'), 'old-hash');
    },
  );
  test(
    'reset commits only a matching server receipt and preserves unrelated storage',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      await f.recovery.enroll('1234');
      expect(await f.recovery.requestLink(), true);
      expect(f.recovery.resendCoolingDown, true);
      f.badReceipt = true;
      expect(await f.recovery.reset(f.link, '2468', '2468'), false);
      expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
      expect(f.resets, 0);
      f.badReceipt = false;
      expect(await f.recovery.reset(f.link, '2468', '2468'), true);
      expect(notePinHash(f.box.get('note_lock_pin')), 'test-hash-2468');
      expect(f.resets, 1);
      expect(f.box.get('unrelated'), 'keep');
      expect(f.recovery.pendingReset, false);
      for (final request in f.requests) {
        expect(request.keys, isNot(contains('pin')));
        expect(request.keys, isNot(contains('hash')));
        expect(request.keys, isNot(contains('email')));
      }
    },
  );
  test(
    'failed local commit can resume the exact authorized operation',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      await f.recovery.enroll('1234');
      f.failWrite = true;
      expect(await f.recovery.reset(f.link, '2468', '2468'), false);
      expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
      expect(f.recovery.pendingReset, true);
      final first = f.requests.last;
      f.failWrite = false;
      expect(await f.recovery.reset(f.link, '2468', '2468'), true);
      expect(f.requests.last['resetId'], first['resetId']);
      expect(f.requests.last['fingerprint'], first['fingerprint']);
      expect(f.hasher.hashes, 1);
      expect(f.resets, 1);
    },
  );
  test(
    'offline reset retains old PIN and refuses a different pending PIN',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      await f.recovery.enroll('1234');
      f.failRedeem = true;
      expect(await f.recovery.reset(f.link, '2468', '2468'), false);
      final count = f.requests.length;
      expect(await f.recovery.reset(f.link, '8642', '8642'), false);
      expect(f.requests.length, count);
      expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
      expect(f.resets, 0);
    },
  );
  test('account switch while redeeming cannot change the local PIN', () async {
    final f = Fixture();
    addTearDown(f.recovery.dispose);
    await f.recovery.enroll('1234');
    f.switchAccount = true;
    expect(await f.recovery.reset(f.link, '2468', '2468'), false);
    expect(notePinHash(f.box.get('note_lock_pin')), 'old-hash');
    expect(f.resets, 0);
    expect(f.recovery.maskedEmail, 'Sign in to the enrolled account');
  });
  test(
    'wrong host and nonmatching confirmation cannot consume a recovery grant',
    () async {
      final f = Fixture();
      addTearDown(f.recovery.dispose);
      await f.recovery.enroll('1234');
      final count = f.requests.length;
      expect(await f.recovery.reset(f.link, '2468', '8642'), false);
      expect(
        await f.recovery.reset(
          f.link.replaceFirst('recovery.example.test', 'other.example.test'),
          '2468',
          '2468',
        ),
        false,
      );
      expect(f.requests.length, count);
      expect(f.recovery.pendingReset, false);
    },
  );
}
