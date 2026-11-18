import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:jot_it/core/services/hive_local_storage_service.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/services/note_cloud_sync.dart';
import 'package:jot_it/features/notes/view/note_cloud_page.dart';

import 'support/fakes.dart';

class CloudUser extends Fake implements User {
  @override
  String get uid => 'owner';
  @override
  String get email => 'writer@example.invalid';
  @override
  bool get emailVerified => true;
}

class CloudMemoryStorage extends Fake implements HiveLocalStorageService {
  Map<String, dynamic> record = {
    'notes': <Note>[],
    'cloud': {'uid': 'owner', 'enabled': true},
  };
  @override
  Map<String, dynamic> readNoteEnvelope(String key) => Map.of(record);
  @override
  Future<void> updateNoteEnvelope(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) async {
    record = update(record);
  }
}

void main() {
  testWidgets(
    'backup browsing and restore confirmation remain reachable on a narrow enlarged screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage(), connection = TestConnection();
      final auth = AuthViewModel(
        authRepository: TestAuthRepository(storage)..user = CloudUser(),
        localBiometricService: TestBiometrics(),
        internetCheckerService: connection,
      );
      final cloud = NoteCloudSync(
        storage: CloudMemoryStorage(),
        identity: () async => const CloudIdentity('owner', 'synthetic', true),
        currentUid: () => 'owner',
        appCheckToken: () async => 'synthetic-app',
        canSync: () => true,
        onChanged: () async {},
        automatic: false,
        endpoint: 'https://cloud.invalid/v1/cloud',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'revision': 1,
              'backups': [
                {
                  'revision': 1,
                  'createdAt': '2026-11-17T00:00:00Z',
                  'count': 3,
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(() {
        cloud.dispose();
        auth.dispose();
        connection.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: NoteCloudPage(cloud: cloud),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Browse backups'), 250);
      await tester.tap(find.text('Browse backups'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Restore', skipOffstage: false),
        200,
      );
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Restore backup copies?'), findsOneWidget);
      expect(find.text('Restore copies'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
