import 'package:flutter/material.dart';
import '../../../../core/utils/random_id_generator.dart';
import '../../model/note_attachment.dart';
import '../../services/note_media_controller.dart';
import 'note_attachment_embed.dart';

Future<NoteAttachment?> showNoteRecorder(
  BuildContext context,
  NoteMediaController media,
) => showModalBottomSheet<NoteAttachment>(
  context: context,
  useRootNavigator: false,
  useSafeArea: true,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => SafeArea(top: false, child: _RecorderSheet(media: media)),
);

class _RecorderSheet extends StatefulWidget {
  const _RecorderSheet({required this.media});
  final NoteMediaController media;
  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet> {
  final _name = TextEditingController(text: 'Voice note');
  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    return ListenableBuilder(
      listenable: media,
      builder: (context, _) {
        final stopped = media.recordingState == NoteRecordingState.stopped;
        final ready = media.recordingState == NoteRecordingState.ready;
        final paused = media.recordingState == NoteRecordingState.paused;
        return PopScope(
          canPop: ready || stopped,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Voice note',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.mic_none, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      formatMediaTime(media.recordingDuration),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      ready
                          ? 'Ready when you are'
                          : stopped
                          ? 'Recording stopped'
                          : paused
                          ? 'Paused'
                          : 'Recording…',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Recording name',
                      ),
                    ),
                    const Text(
                      'Up to two minutes. Microphone access is requested only when you start recording.',
                    ),
                    if (media.recordingNotice != null) ...[
                      const SizedBox(height: 12),
                      Text(media.recordingNotice!),
                    ],
                    if (media.error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          media.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (ready)
                      FilledButton.icon(
                        onPressed: media.recordingBusy
                            ? null
                            : media.startRecording,
                        icon: const Icon(Icons.mic),
                        label: const Text('Start recording'),
                      )
                    else if (stopped)
                      FilledButton.icon(
                        onPressed: !media.hasRecording
                            ? null
                            : () {
                                final name = _name.text.trim();
                                Navigator.pop(
                                  context,
                                  NoteAttachment(
                                    id: RandomId().generate(),
                                    name:
                                        '${name.isEmpty ? 'Voice note' : name}.wav',
                                    mimeType: 'audio/wav',
                                    bytes: media.recordedBytes!,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Attach recording'),
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: media.recordingBusy
                            ? null
                            : media.toggleRecordingPause,
                        icon: Icon(paused ? Icons.mic : Icons.pause),
                        label: Text(paused ? 'Resume' : 'Pause'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: media.recordingBusy
                            ? null
                            : media.stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop recording'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: media.recordingBusy
                          ? null
                          : () async {
                              await media.discardRecording();
                              if (context.mounted) Navigator.pop(context);
                            },
                      child: Text(ready ? 'Cancel' : 'Discard recording'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
