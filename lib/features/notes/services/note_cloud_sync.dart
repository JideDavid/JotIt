import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/hive_local_storage_service.dart';
import '../model/note.dart';
import 'note_sync_merge.dart';

class CloudIdentity {
  const CloudIdentity(this.uid, this.token, this.verified);
  final String uid, token;
  final bool verified;
}

class CloudBackup {
  const CloudBackup(this.revision, this.createdAt, this.count);
  final int revision, count;
  final DateTime createdAt;
}

class _CloudFailure implements Exception {
  const _CloudFailure(this.message, [this.status]);
  final String message;
  final int? status;
}

class NoteCloudSync extends ChangeNotifier {
  NoteCloudSync({
    required this.storage,
    required this.identity,
    required this.currentUid,
    required this.appCheckToken,
    required this.canSync,
    required this.onChanged,
    this.endpoint = const String.fromEnvironment('JOTIT_CLOUD_URL'),
    http.Client? client,
    bool automatic = true,
  }) : _client = client ?? http.Client() {
    if (automatic) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (enabled && matchesAccount && canSync() && !busy) unawaited(sync());
      });
    }
  }

  final HiveLocalStorageService storage;
  final Future<CloudIdentity?> Function() identity;
  final String? Function() currentUid;
  final Future<String?> Function() appCheckToken;
  final bool Function() canSync;
  final Future<void> Function() onChanged;
  final String endpoint;
  final http.Client _client;
  Timer? _timer, _debounce;
  bool _disposed = false, _busy = false;
  String? error, notice;
  List<CloudBackup> _backups = [];
  List<CloudBackup> get backups =>
      matchesAccount ? List.unmodifiable(_backups) : const [];
  bool get busy => _busy;
  Map<String, dynamic> get _record => storage.readNoteEnvelope('all');
  Map<String, dynamic> get _state =>
      Map<String, dynamic>.from(_record['cloud'] as Map? ?? const {});
  bool get enabled => _state['enabled'] == true;
  bool get matchesAccount =>
      _state['uid'] != null && _state['uid'] == currentUid();
  int get revision => _state['revision'] as int? ?? 0;
  DateTime? get lastSync =>
      DateTime.tryParse(_state['lastSync'] as String? ?? '');
  bool get configured {
    final uri = Uri.tryParse(endpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.path == '/v1/cloud';
  }

  /// Called after a saved library mutation. Unsaved editor state is never read.
  void localChanged() {
    if (_disposed || busy) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      if (enabled && matchesAccount && canSync()) unawaited(sync());
    });
    notifyListeners();
  }

  void _check(String uid) {
    if (_disposed || currentUid() != uid || !canSync()) {
      throw const _CloudFailure(
        'Close the editor, unlock JotIt and sign in to the connected account to sync.',
      );
    }
    final owner = _state['uid'];
    if (owner != null && owner != uid) {
      throw const _CloudFailure(
        'This library is connected to another account. Sign in to that account to sync.',
      );
    }
  }

  Future<CloudIdentity> _account() async {
    if (!configured) {
      throw const _CloudFailure(
        'Cloud backup is not configured in this build. Your notes stay on this device.',
      );
    }
    final account = await identity().timeout(const Duration(seconds: 15));
    if (account == null || !account.verified || account.token.isEmpty) {
      throw const _CloudFailure(
        'Sign in with a verified Google account to use cloud backup.',
      );
    }
    _check(account.uid);
    return account;
  }

  Future<Map<String, dynamic>> _post(
    String action,
    CloudIdentity account, [
    Map<String, dynamic> body = const {},
  ]) async {
    _check(account.uid);
    final token = await appCheckToken().timeout(const Duration(seconds: 15));
    _check(account.uid);
    if (token == null || token.isEmpty) {
      throw const _CloudFailure('Could not verify this app. Retry cloud sync.');
    }
    final response = await _client
        .post(
          Uri.parse('$endpoint/$action'),
          headers: {
            'Authorization': 'Bearer ${account.token}',
            'X-Firebase-AppCheck': token,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));
    _check(account.uid);
    if (response.statusCode != 200) {
      throw _CloudFailure(switch (response.statusCode) {
        401 || 403 => 'Sign in again and verify this app before syncing.',
        409 =>
          'Another device updated your notes. Retry sync; local edits are safe.',
        410 => 'This backup is no longer available. Refresh the backup list.',
        413 =>
          'This library exceeds the 64 MiB cloud backup limit. Nothing was skipped.',
        429 => 'Cloud requests are temporarily limited. Retry later.',
        _ => 'Cloud sync is unavailable. Your saved local notes are unchanged.',
      }, response.statusCode);
    }
    if (response.bodyBytes.length > NoteBackupCodec.maxBytes + 16384) {
      throw const _CloudFailure(
        'The cloud response exceeds the backup size limit.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw const _CloudFailure('Cloud returned an invalid response.');
    }
    return Map<String, dynamic>.from(data);
  }

  int _revision(Map<String, dynamic> response) {
    final value = response['revision'];
    if (value is! int || value < 0) {
      throw const _CloudFailure('Cloud returned an invalid revision.');
    }
    return value;
  }

  List<Note> _notes(Map<String, dynamic> response) => NoteBackupCodec.decode(
    utf8.encode(jsonEncode({'schema': 1, 'notes': response['notes']})),
  );

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    _busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on _CloudFailure catch (failure) {
      error = failure.message;
      return false;
    } on FormatException {
      error =
          'This library could not be validated for backup. It may exceed 64 MiB or contain unsupported data. Your local notes are unchanged.';
      return false;
    } catch (_) {
      error =
          'Could not finish cloud sync. Your local notes are safe; retry when connected.';
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> connect({String? expectedUid}) => _run(() async {
    final account = await _account();
    if (expectedUid != null && account.uid != expectedUid) {
      throw const _CloudFailure(
        'The signed-in account changed. Review the connection again.',
      );
    }
    await storage.updateNoteEnvelope('all', (record) {
      _check(account.uid);
      return {
        ...record,
        'cloud': {..._state, 'uid': account.uid, 'enabled': true},
      };
    });
    await _sync(account);
  });

  Future<bool> pause() => _run(() async {
    final uid = currentUid();
    if (uid == null) {
      throw const _CloudFailure(
        'Sign in to the connected account to pause sync.',
      );
    }
    _check(uid);
    await storage.updateNoteEnvelope('all', (record) {
      _check(uid);
      return {
        ...record,
        'cloud': {..._state, 'enabled': false},
      };
    });
    notice = 'Sync paused. Your local notes and cloud backups are kept.';
  });

  Future<bool> sync() => _run(() async {
    final account = await _account();
    if (!enabled) throw const _CloudFailure('Connect cloud backup first.');
    await _sync(account);
  });

  String _operation() => base64UrlEncode(
    List.generate(32, (_) => _random.nextInt(256)),
  ).replaceAll('=', '');
  final _random = Random.secure();

  Future<void> _sync(CloudIdentity account) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      _check(account.uid);
      if (!enabled) throw const _CloudFailure('Sync is paused.');
      final record = _record, state = _state;
      final local = List<Note>.from(record['notes'] as List);
      final before = List<Note>.from(state['base'] as List? ?? const []);
      final localBytes = NoteBackupCodec.encode(local);
      final head = await _post('history', account);
      final headRevision = _revision(head);
      final response = headRevision == (state['revision'] ?? 0)
          ? {
              'revision': headRevision,
              'notes': before.map(NoteBackupCodec.noteJson).toList(),
            }
          : await _post('read', account);
      final remoteRevision = _revision(response), remote = _notes(response);
      final merged = await NoteSyncMerge.reconcile(
        base: before,
        local: local,
        remote: remote,
      );
      final mergedBytes = NoteBackupCodec.encode(merged.notes);
      var committedRevision = remoteRevision;
      if (!listEquals(mergedBytes, NoteBackupCodec.encode(remote))) {
        try {
          final commit = await _post('write', account, {
            'expectedRevision': remoteRevision,
            'operationId': _operation(),
            'notes': merged.notes.map(NoteBackupCodec.noteJson).toList(),
          });
          committedRevision = _revision(commit);
          if (committedRevision != remoteRevision + 1) {
            throw const _CloudFailure(
              'Cloud did not acknowledge this backup. Retry sync.',
            );
          }
        } on _CloudFailure catch (failure) {
          if (failure.status == 409 && attempt < 2) continue;
          rethrow;
        }
      }
      await storage.updateNoteEnvelope('all', (latest) {
        _check(account.uid);
        if (!enabled ||
            !listEquals(
              localBytes,
              NoteBackupCodec.encode(List<Note>.from(latest['notes'] as List)),
            )) {
          throw const _CloudFailure(
            'Local notes changed during sync. Retry to include the latest edits.',
          );
        }
        return {
          ...latest,
          'notes': merged.notes,
          'cloud': {
            ...state,
            'uid': account.uid,
            'enabled': true,
            'revision': committedRevision,
            'base': merged.notes,
            'lastSync': DateTime.now().toUtc().toIso8601String(),
          },
        };
      });
      await onChanged();
      notice = merged.conflicts > 0
          ? 'Synced. ${merged.conflicts} conflicts were found; edited versions were kept.'
          : 'All saved notes are synced.';
      return;
    }
  }

  Future<bool> loadBackups() => _run(() async {
    final account = await _account();
    final response = await _post('history', account);
    final raw = response['backups'];
    if (raw is! List || raw.length > 20) {
      throw const _CloudFailure('Cloud returned an invalid backup list.');
    }
    final result = <CloudBackup>[];
    for (final item in raw) {
      if (item is! Map ||
          item['revision'] is! int ||
          item['revision'] < 1 ||
          item['count'] is! int ||
          item['count'] < 0 ||
          item['createdAt'] is! String ||
          DateTime.tryParse(item['createdAt']) == null) {
        throw const _CloudFailure('Cloud returned an invalid backup list.');
      }
      result.add(
        CloudBackup(
          item['revision'],
          DateTime.parse(item['createdAt']),
          item['count'],
        ),
      );
    }
    _check(account.uid);
    _backups = result;
  });

  Future<bool> restore(CloudBackup backup) => _run(() async {
    final account = await _account();
    if (!matchesAccount || _state['uid'] == null) {
      throw const _CloudFailure('Connect this account before restoring.');
    }
    final response = await _post('read', account, {
      'revision': backup.revision,
    });
    if (_revision(response) != backup.revision) {
      throw const _CloudFailure('Cloud returned a different backup.');
    }
    final recovered = _notes(response);
    final restoredIds = <String, String>{};
    for (final note in recovered) {
      final digest = await Sha256().hash(
        utf8.encode('${backup.revision}\n${note.id}'),
      );
      restoredIds[note.id] =
          'restore-${digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    }
    await storage.updateNoteEnvelope('all', (record) {
      _check(account.uid);
      final notes = List<Note>.from(record['notes'] as List);
      final signatures = notes.map(NoteBackupCodec.signature).toSet();
      final ids = notes.map((note) => note.id).toSet();
      for (final note in recovered) {
        if (signatures.contains(NoteBackupCodec.signature(note))) {
          continue;
        }
        final id = restoredIds[note.id]!;
        if (!ids.add(id)) continue;
        notes.add(
          Note(
            id: id,
            title: '${note.title} (restored copy)',
            body: note.body,
            timestamp: DateTime.now(),
            color: note.color,
            isLocked: note.isLocked,
            richText: note.richText,
            paper: note.paper,
            media: note.media,
          ),
        );
      }
      NoteBackupCodec.encode(notes);
      return {...record, 'notes': notes};
    });
    await onChanged();
    notice =
        'Backup restored as copies. Existing notes were kept. Sync to back up the restored copies.';
  });

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _debounce?.cancel();
    _client.close();
    super.dispose();
  }
}
