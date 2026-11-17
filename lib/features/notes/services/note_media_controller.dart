import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import '../model/note_attachment.dart';

abstract class NoteRecorderBackend {
  Future<bool> hasPermission();
  Future<Stream<Uint8List>> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class PluginNoteRecorder implements NoteRecorderBackend {
  AudioRecorder? _recorder;
  AudioRecorder get _instance => _recorder ??= AudioRecorder();

  @override
  Future<bool> hasPermission() => _instance.hasPermission();
  @override
  Future<Stream<Uint8List>> start() => _instance.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
    ),
  );
  @override
  Future<void> pause() => _instance.pause();
  @override
  Future<void> resume() => _instance.resume();
  @override
  Future<void> stop() async {
    await _recorder?.stop();
  }

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
  }
}

enum NoteRecordingState { ready, starting, recording, paused, stopped }

class NoteMediaController extends ChangeNotifier with WidgetsBindingObserver {
  NoteMediaController({
    NoteRecorderBackend? recorder,
    AudioPlayer Function()? createPlayer,
  }) : _recorder = recorder ?? PluginNoteRecorder(),
       _createPlayer = createPlayer ?? AudioPlayer.new {
    WidgetsBinding.instance.addObserver(this);
  }

  final NoteRecorderBackend _recorder;
  final AudioPlayer Function() _createPlayer;
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];
  StreamSubscription<Uint8List>? _recordSubscription;
  BytesBuilder _pcm = BytesBuilder(copy: false);
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  bool _disposed = false;
  bool _allowed = true;
  bool _sessionAllowed = true;
  bool _foreground = true;
  bool _stopping = false;
  Future<void>? _stopOperation;
  bool _playBusy = false;
  int _generation = 0;
  NoteRecordingState recordingState = NoteRecordingState.ready;
  Uint8List? recordedBytes;
  String? error;
  String? recordingNotice;
  String? playingId;
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration get recordingDuration => _watch.elapsed;
  bool get recordingBusy =>
      recordingState == NoteRecordingState.starting || _stopping;
  bool get hasRecording => recordedBytes != null && recordedBytes!.length > 44;
  bool get playbackBusy => _playBusy;
  bool get playbackAllowed => _allowed;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setPrivacyAllowed(bool allowed) {
    _sessionAllowed = allowed;
    _updatePrivacy();
  }

  void _updatePrivacy() {
    final allowed = _sessionAllowed && _foreground;
    if (_allowed == allowed) return;
    _allowed = allowed;
    if (!allowed) {
      _generation++;
      unawaited(stopPlayback());
      unawaited(
        stopRecording(
          notice:
              'Recording stopped while the app was inactive. Review before attaching.',
        ),
      );
    }
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _foreground = false;
      _updatePrivacy();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _updatePrivacy();
    }
  }

  Future<void> startRecording() async {
    if (_disposed ||
        !_allowed ||
        recordingBusy ||
        recordingState != NoteRecordingState.ready) {
      return;
    }
    final generation = _generation;
    recordingState = NoteRecordingState.starting;
    error = null;
    recordingNotice = null;
    _notify();
    try {
      await stopPlayback();
      if (!await _recorder.hasPermission()) {
        error =
            'Microphone access is denied. Allow it in your device or browser settings, or attach an audio file.';
        recordingState = NoteRecordingState.ready;
        return;
      }
      if (_disposed || !_allowed || generation != _generation) {
        recordingState = NoteRecordingState.ready;
        return;
      }
      final stream = await _recorder.start();
      if (_disposed || !_allowed || generation != _generation) {
        await _recorder.stop();
        recordingState = NoteRecordingState.ready;
        return;
      }
      _pcm = BytesBuilder(copy: false);
      recordedBytes = null;
      _watch
        ..reset()
        ..start();
      recordingState = NoteRecordingState.recording;
      _recordSubscription = stream.listen(
        (chunk) {
          if (_disposed || recordingState != NoteRecordingState.recording) {
            return;
          }
          if (_pcm.length + chunk.length > NoteAttachment.maxFileBytes - 44) {
            unawaited(
              stopRecording(notice: 'The recording reached the 5 MB limit.'),
            );
            return;
          }
          _pcm.add(Uint8List.fromList(chunk));
        },
        onError: (Object _) {
          error =
              'Recording was interrupted. You can keep the audio captured so far.';
          unawaited(stopRecording());
        },
        onDone: () {
          if (!_stopping && !_disposed) unawaited(stopRecording());
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_watch.elapsed >= const Duration(minutes: 2)) {
          unawaited(
            stopRecording(
              notice: 'The recording reached the two-minute limit.',
            ),
          );
        } else {
          _notify();
        }
      });
    } catch (_) {
      error =
          'Could not start recording. Check microphone access or attach an audio file instead.';
      recordingState = NoteRecordingState.ready;
      try {
        await _recorder.stop();
      } catch (_) {}
    } finally {
      _notify();
    }
  }

  Future<void> toggleRecordingPause() async {
    if (_disposed || !_allowed || recordingBusy) return;
    final generation = _generation;
    try {
      if (recordingState == NoteRecordingState.recording) {
        await _recorder.pause();
        if (_disposed || !_allowed || generation != _generation) return;
        _watch.stop();
        recordingState = NoteRecordingState.paused;
      } else if (recordingState == NoteRecordingState.paused) {
        await _recorder.resume();
        if (_disposed || !_allowed || generation != _generation) {
          await stopRecording();
          return;
        }
        _watch.start();
        recordingState = NoteRecordingState.recording;
      }
    } catch (_) {
      error =
          'Could not pause or resume. Stop recording to keep the captured audio.';
    }
    _notify();
  }

  Future<void> stopRecording({String? notice}) {
    if (_stopOperation != null) return _stopOperation!;
    if (recordingState == NoteRecordingState.ready ||
        recordingState == NoteRecordingState.stopped) {
      return Future.value();
    }
    if (recordingState == NoteRecordingState.starting) {
      _generation++;
      return Future.value();
    }
    final operation = _stopRecording(notice);
    _stopOperation = operation;
    return operation.whenComplete(() => _stopOperation = null);
  }

  Future<void> _stopRecording(String? notice) async {
    _stopping = true;
    _watch.stop();
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {
      error = 'The recorder stopped unexpectedly. Review the captured audio.';
    } finally {
      await _recordSubscription?.cancel();
      _recordSubscription = null;
      recordedBytes = _pcm.length < 2 ? null : wavFromPcm(_pcm.toBytes());
      recordingState = NoteRecordingState.stopped;
      recordingNotice = notice;
      _stopping = false;
      _notify();
    }
  }

  Future<void> discardRecording() async {
    _generation++;
    await stopRecording();
    _pcm.clear();
    recordedBytes = null;
    _watch.reset();
    recordingState = NoteRecordingState.ready;
    recordingNotice = null;
    error = null;
    _notify();
  }

  Future<void> togglePlayback(NoteAttachment attachment) async {
    if (_disposed ||
        !_allowed ||
        _playBusy ||
        recordingState == NoteRecordingState.recording ||
        recordingState == NoteRecordingState.paused) {
      return;
    }
    _playBusy = true;
    final generation = _generation;
    final previousId = playingId;
    playingId = attachment.id;
    error = null;
    _notify();
    try {
      final player = _player ??= _createPlayer();
      if (_playerSubscriptions.isEmpty) {
        _playerSubscriptions.addAll([
          player.onPositionChanged.listen((value) {
            position = value;
            _notify();
          }, onError: _playbackFailed),
          player.onDurationChanged.listen((value) {
            duration = value;
            _notify();
          }, onError: _playbackFailed),
          player.onPlayerStateChanged.listen((value) {
            playing = value == PlayerState.playing;
            _notify();
          }, onError: _playbackFailed),
        ]);
      }
      if (previousId == attachment.id && playing) {
        await player.pause();
      } else if (previousId == attachment.id &&
          player.state == PlayerState.paused) {
        await player.resume();
      } else {
        await player.stop();
        playingId = attachment.id;
        duration = Duration.zero;
        position = Duration.zero;
        await player.play(
          BytesSource(attachment.bytes, mimeType: attachment.mimeType),
        );
      }
      if (_disposed || !_allowed || generation != _generation) {
        await player.stop();
      }
    } catch (failure) {
      _playbackFailed(failure);
    } finally {
      _playBusy = false;
      _notify();
    }
  }

  void _playbackFailed(Object failure) {
    if (_disposed) return;
    debugPrint('Audio playback failed (${failure.runtimeType}).');
    error =
        'Could not play this audio. The file may be damaged or unsupported by this device.';
    playing = false;
    _notify();
  }

  Future<void> seek(Duration value) async {
    if (!_allowed || _disposed) return;
    try {
      await _player?.seek(value);
    } catch (_) {
      error = 'Could not seek in this audio.';
      _notify();
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player?.stop();
    } catch (_) {}
    playing = false;
    _notify();
  }

  static Uint8List wavFromPcm(Uint8List pcm) {
    final length = pcm.length - pcm.length % 2;
    final output = Uint8List(44 + length);
    final header = ByteData.sublistView(output);
    output.setAll(0, 'RIFF'.codeUnits);
    header.setUint32(4, 36 + length, Endian.little);
    output.setAll(8, 'WAVEfmt '.codeUnits);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 16000, Endian.little);
    header.setUint32(28, 32000, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    output.setAll(36, 'data'.codeUnits);
    header.setUint32(40, length, Endian.little);
    output.setRange(44, output.length, pcm);
    return output;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _watch.stop();
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_recordSubscription?.cancel());
    unawaited(_releaseDevices());
    super.dispose();
  }

  Future<void> _releaseDevices() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
    try {
      await _player?.dispose();
    } catch (_) {}
  }
}
