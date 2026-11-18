import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jot_it/core/services/hive_local_storage_service.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/services/note_cloud_sync.dart';
import 'package:jot_it/features/notes/services/note_sync_merge.dart';

import 'support/fakes.dart';

class TestCloud {
  int revision = 0;
  List<dynamic> notes = [];
  final history = <int, List<dynamic>>{};
  final requests = <http.Request>[];
  Future<void> Function(String action)? intercept;
  bool offline = false;
  Future<http.Response> call(http.Request request) async {
    requests.add(request);
    if (offline) throw const SocketException('synthetic offline');
    final action = request.url.pathSegments.last;
    await intercept?.call(action);
    final body = jsonDecode(request.body) as Map;
    if (action == 'history') {
      return response({
        'revision': revision,
        'backups': history.keys
            .toList()
            .reversed
            .map(
              (r) => {
                'revision': r,
                'count': history[r]!.length,
                'createdAt': '2026-11-17T00:00:00Z',
              },
            )
            .toList(),
      });
    }
    if (action == 'read') {
      final r = body['revision'] ?? revision;
      return response({'revision': r, 'notes': r == 0 ? [] : history[r]});
    }
    if (body['expectedRevision'] != revision) return http.Response('{}', 409);
    notes = List<dynamic>.from(body['notes']);
    history[++revision] = jsonDecode(jsonEncode(notes));
    return response({'revision': revision});
  }

  http.Response response(Object value) => http.Response(jsonEncode(value), 200);
}

class FaultStorage extends HiveLocalStorageService {
  FaultStorage(super.auth, super.notes);
  bool failNext = false;
  @override
  Future<void> updateNoteEnvelope(
    String key,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) {
    if (failNext) {
      failNext = false;
      return Future.error(StateError('synthetic disk failure'));
    }
    return super.updateNoteEnvelope(key, update);
  }
}

class Device {
  Device(
    this.storage,
    this.cloud, {
    String endpoint = 'https://cloud.example/v1/cloud',
  }) {
    sync = NoteCloudSync(
      storage: storage,
      identity: () async =>
          uid == null ? null : CloudIdentity(uid!, 'synthetic-token', verified),
      currentUid: () => uid,
      appCheckToken: () async => 'synthetic-attestation',
      canSync: () => ready,
      onChanged: () async {
        changes++;
      },
      endpoint: endpoint,
      client: MockClient(cloud.call),
      automatic: false,
    );
  }
  final FaultStorage storage;
  final TestCloud cloud;
  late final NoteCloudSync sync;
  String? uid = 'owner';
  bool ready = true, verified = true;
  int changes = 0;
  List<Note> get notes => storage.getNotes('all');
  Future<void> save(List<Note> notes) => storage.saveNotes(notes, 'all');
}

void main() {
  test('connection consent is bound to the reviewed account', () async {
    final directory = await Directory.systemTemp.createTemp('jotit-consent-');
    Hive.init(directory.path);
    final cloud = TestCloud();
    final storage = HiveLocalStorageService(
      await Hive.openBox('consentAuth'),
      await Hive.openBox('consentNotes'),
    );
    final sync = NoteCloudSync(
      storage: storage,
      identity: () async => const CloudIdentity('different', 'synthetic', true),
      currentUid: () => 'different',
      appCheckToken: () async => 'synthetic',
      canSync: () => true,
      onChanged: () async {},
      endpoint: 'https://cloud.invalid/v1/cloud',
      automatic: false,
      client: MockClient(cloud.call),
    );
    try {
      expect(await sync.connect(expectedUid: 'reviewed'), false);
      expect(cloud.requests, isEmpty);
      expect(sync.enabled, false);
    } finally {
      sync.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late TestCloud remote;
  final devices = <Device>[];
  setUpAll(() {
    Hive.registerAdapter(NoteAdapter());
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jotit-cloud-');
    Hive.init(directory.path);
    remote = TestCloud();
  });
  tearDown(() async {
    for (final d in devices) {
      d.sync.dispose();
    }
    devices.clear();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<Device> device({
    String endpoint = 'https://cloud.example/v1/cloud',
  }) async {
    final i = devices.length;
    final d = Device(
      FaultStorage(await Hive.openBox('auth$i'), await Hive.openBox('notes$i')),
      remote,
      endpoint: endpoint,
    );
    devices.add(d);
    return d;
  }

  test(
    'opt-in uploads locked notes and media without PINs; another device restores',
    () async {
      final a = await device(), b = await device();
      await a.save([makeNote('a', body: 'private', isLocked: true)]);
      expect(remote.requests, isEmpty);
      expect(await a.sync.connect(), true);
      expect(await b.sync.connect(), true);
      expect(b.notes.single.isLocked, true);
      expect(b.notes.single.body, 'private');
      expect(b.storage.hasNoteLockPin(), false);
      expect(
        remote.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer synthetic-token',
        ),
        true,
      );
      expect(
        remote.requests.map((r) => r.body).join(),
        isNot(contains('note_lock_pin')),
      );
    },
  );

  test(
    'two offline devices preserve conflicting edits and propagate acknowledged deletion',
    () async {
      final a = await device(), b = await device();
      await a.save([makeNote('a', body: 'original')]);
      await a.sync.connect();
      await b.sync.connect();
      await a.save([makeNote('a', body: 'first edit')]);
      await b.save([makeNote('a', body: 'second edit')]);
      expect(await a.sync.sync(), true);
      expect(await b.sync.sync(), true);
      expect(b.notes.map((n) => n.body).toSet(), {'first edit', 'second edit'});
      expect(await a.sync.sync(), true);
      expect(a.notes.length, 2);
      await a.save([]);
      expect(await a.sync.sync(), true);
      expect(await b.sync.sync(), true);
      expect(b.notes, isEmpty);
    },
  );

  test(
    'lost local acknowledgement retries without duplicate conflict copies',
    () async {
      final a = await device();
      await a.save([makeNote('a')]);
      remote.intercept = (action) async {
        if (action == 'write') a.storage.failNext = true;
      };
      expect(await a.sync.connect(), false);
      expect(remote.revision, 1);
      expect(a.sync.revision, 0);
      remote.intercept = null;
      expect(await a.sync.sync(), true);
      expect(a.sync.revision, 1);
      expect(remote.revision, 1);
      expect(a.notes.length, 1);
    },
  );

  test(
    'sign-out and account changes cannot commit a late cloud result or adopt another account',
    () async {
      final a = await device();
      await a.save([makeNote('a')]);
      await a.sync.connect();
      await a.save([makeNote('a', body: 'local edit')]);
      remote.intercept = (action) async {
        if (action == 'history') a.uid = 'other';
      };
      expect(await a.sync.sync(), false);
      expect(remote.revision, 1);
      expect(a.notes.single.body, 'local edit');
      remote.intercept = null;
      final count = remote.requests.length;
      expect(await a.sync.connect(), false);
      expect(remote.requests.length, count);
      a.uid = null;
      expect(await a.sync.sync(), false);
    },
  );

  test(
    'local changes during a cloud request remain pending instead of being overwritten',
    () async {
      final a = await device();
      await a.save([makeNote('a')]);
      await a.sync.connect();
      remote.intercept = (action) async {
        if (action == 'history') {
          await a.save([makeNote('a', body: 'newer local')]);
        }
      };
      expect(await a.sync.sync(), false);
      expect(a.notes.single.body, 'newer local');
      remote.intercept = null;
      expect(await a.sync.sync(), true);
      expect((remote.notes.single as Map)['body'], 'newer local');
    },
  );

  test(
    'offline failure and editor/background gates leave local data intact',
    () async {
      final a = await device();
      await a.save([makeNote('a')]);
      remote.offline = true;
      expect(await a.sync.connect(), false);
      expect(a.notes.single.id, 'a');
      expect(a.sync.lastSync, null);
      remote.offline = false;
      a.ready = false;
      final count = remote.requests.length;
      expect(await a.sync.sync(), false);
      expect(remote.requests.length, count);
      a.ready = true;
      expect(await a.sync.sync(), true);
      expect(await a.sync.pause(), true);
      expect(await a.sync.sync(), false);
      expect(a.notes.length, 1);
    },
  );

  test(
    'restore keeps existing edits, locked flags and idempotent recovered copies',
    () async {
      final a = await device();
      await a.save([makeNote('a', body: 'old', isLocked: true)]);
      await a.sync.connect();
      await a.save([makeNote('a', body: 'new')]);
      await a.sync.sync();
      expect(await a.sync.loadBackups(), true);
      final old = a.sync.backups.last;
      expect(await a.sync.restore(old), true);
      expect(a.notes.map((n) => n.body).toSet(), {'old', 'new'});
      expect(a.notes.singleWhere((n) => n.body == 'old').isLocked, true);
      expect(await a.sync.restore(old), true);
      expect(a.notes.length, 2);
      expect(await a.sync.sync(), true);
      expect(remote.notes.length, 2);
    },
  );

  test(
    'unchanged libraries check metadata without downloading full media snapshots',
    () async {
      final a = await device();
      await a.save([makeNote('a')]);
      await a.sync.connect();
      remote.requests.clear();
      expect(await a.sync.sync(), true);
      expect(remote.requests.map((r) => r.url.pathSegments.last), ['history']);
    },
  );

  test(
    'unconfigured and unverified clients cannot upload or claim a cloud account',
    () async {
      final a = await device(endpoint: '');
      expect(await a.sync.connect(), false);
      expect(a.sync.enabled, false);
      expect(remote.requests, isEmpty);
      final b = await device();
      b.verified = false;
      expect(await b.sync.connect(), false);
      expect(b.sync.enabled, false);
      expect(remote.requests, isEmpty);
    },
  );

  test(
    'legacy lists migrate atomically and sync metadata survives local note writes and reopen',
    () async {
      final a = await device();
      final box = Hive.box<dynamic>('notes0');
      await box.put('all', [makeNote('legacy')]);
      expect(await a.sync.connect(), true);
      await a.save([makeNote('legacy', body: 'edit')]);
      expect(a.sync.revision, 1);
      expect(a.sync.enabled, true);
      await box.close();
      await Hive.openBox('notes0');
      final reopened = HiveLocalStorageService(
        Hive.box('auth0'),
        Hive.box('notes0'),
      );
      expect(reopened.getNotes('all').single.body, 'edit');
      expect((reopened.readNoteEnvelope('all')['cloud'] as Map)['revision'], 1);
      expect(NoteBackupCodec.encode(reopened.getNotes('all')), isNotEmpty);
    },
  );
}
