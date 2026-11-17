import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note_attachment.dart';
import 'package:jot_it/features/notes/services/note_media_controller.dart';

class _Player extends Fake implements AudioPlayer {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration>.broadcast(sync: true);
  final states = StreamController<PlayerState>.broadcast(sync: true);
  Completer<void>? pending;
  int starts = 0;
  int stops = 0;
  Duration? sought;
  @override
  PlayerState state = PlayerState.stopped;
  @override
  Stream<Duration> get onPositionChanged => positions.stream;
  @override
  Stream<Duration> get onDurationChanged => durations.stream;
  @override
  Stream<PlayerState> get onPlayerStateChanged => states.stream;

  void changeState(PlayerState value) {
    state = value;
    states.add(value);
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    starts++;
    expect(source, isA<BytesSource>());
    await pending?.future;
    changeState(PlayerState.playing);
  }

  @override
  Future<void> pause() async => changeState(PlayerState.paused);
  @override
  Future<void> resume() async => changeState(PlayerState.playing);
  @override
  Future<void> stop() async {
    stops++;
    changeState(PlayerState.stopped);
  }

  @override
  Future<void> seek(Duration position) async => sought = position;
  @override
  Future<void> dispose() async {
    await positions.close();
    await durations.close();
    await states.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Player player;
  late NoteMediaController media;
  final attachment = NoteAttachment(
    id: 'sample',
    name: 'Voice.wav',
    mimeType: 'audio/wav',
    bytes: NoteMediaController.wavFromPcm(Uint8List(32000)),
  );
  setUp(() {
    player = _Player();
    media = NoteMediaController(createPlayer: () => player);
  });
  tearDown(() => media.dispose());

  test(
    'play, pause, resume, seek and duration stay in the same player',
    () async {
      await media.togglePlayback(attachment);
      expect(media.playingId, 'sample');
      expect(media.playing, true);
      player.durations.add(const Duration(seconds: 20));
      player.positions.add(const Duration(seconds: 4));
      expect(media.duration.inSeconds, 20);
      expect(media.position.inSeconds, 4);
      await media.togglePlayback(attachment);
      expect(media.playing, false);
      expect(player.state, PlayerState.paused);
      await media.togglePlayback(attachment);
      expect(media.playing, true);
      expect(player.starts, 1);
      await media.seek(const Duration(seconds: 8));
      expect(player.sought!.inSeconds, 8);
    },
  );

  test(
    'pending playback cannot duplicate or continue behind a privacy lock',
    () async {
      player.pending = Completer<void>();
      final playing = media.togglePlayback(attachment);
      await Future<void>.delayed(Duration.zero);
      expect(media.playbackBusy, true);
      await media.togglePlayback(attachment);
      expect(player.starts, 1);
      media.setPrivacyAllowed(false);
      player.pending!.complete();
      await playing;
      expect(player.state, PlayerState.stopped);
      expect(media.playing, false);
      expect(media.playbackBusy, false);
      media.setPrivacyAllowed(true);
      expect(player.state, PlayerState.stopped);
    },
  );

  test(
    'backgrounding stops playback and never automatically resumes it',
    () async {
      await media.togglePlayback(attachment);
      media.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      expect(media.playing, false);
      await media.togglePlayback(attachment);
      expect(player.starts, 1);
      media.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(media.playing, false);
    },
  );

  test(
    'playback stream errors become retryable UI errors, not uncaught errors',
    () async {
      await media.togglePlayback(attachment);
      player.durations.addError(StateError('Unsupported codec'));
      player.positions.addError(StateError('Playback failed'));
      expect(media.error, contains('Could not play this audio'));
      expect(media.playing, false);
      await media.togglePlayback(attachment);
      expect(media.error, isNull);
      expect(media.playing, true);
    },
  );
}
