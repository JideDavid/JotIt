import 'package:flutter/material.dart';
import 'note_attachment_drag.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../model/note_attachment.dart';
import '../../view-model/note_view_model.dart';
import '../../services/note_media_controller.dart';

class NoteAttachmentEmbedBuilder extends EmbedBuilder {
  NoteAttachmentEmbedBuilder({required this.notes, required this.media});
  final NoteViewModel notes;
  final NoteMediaController media;

  @override
  String get key => NoteAttachment.embedType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    final id = data is String ? data : '';
    final attachment = notes.attachmentById(id);
    if (attachment == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'This attachment is unavailable. Your text is still intact.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (attachment.kind == NoteAttachmentKind.image)
              Tooltip(
                message: 'View image ${attachment.name}',
                child: InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    useRootNavigator: false,
                    builder: (context) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Close image',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          Flexible(
                            child: InteractiveViewer(
                              child: Image.memory(
                                attachment.bytes,
                                fit: BoxFit.contain,
                                cacheWidth: 1600,
                                errorBuilder: (_, error, stack) =>
                                    const Text('Could not display this image.'),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(attachment.name),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: Image.memory(
                    attachment.bytes,
                    height: 190,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    cacheWidth: 1000,
                    errorBuilder: (_, error, stack) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Could not display this image.'),
                    ),
                  ),
                ),
              )
            else
              ListenableBuilder(
                listenable: media,
                builder: (context, _) {
                  final selected = media.playingId == attachment.id;
                  final duration = selected ? media.duration : Duration.zero;
                  final position = selected ? media.position : Duration.zero;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: selected && media.playing
                                  ? 'Pause audio'
                                  : 'Play audio',
                              onPressed:
                                  media.playbackAllowed && !media.playbackBusy
                                  ? () => media.togglePlayback(attachment)
                                  : null,
                              icon: selected && media.playbackBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      selected && media.playing
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachment.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          semanticFormatterCallback: (value) =>
                              '${value.round()} seconds',
                          label: 'Audio position',
                          min: 0,
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds / 1000
                              : 1,
                          value: duration.inMilliseconds > 0
                              ? (position.inMilliseconds / 1000).clamp(
                                  0,
                                  duration.inMilliseconds / 1000,
                                )
                              : 0,
                          onChanged: duration.inMilliseconds > 0
                              ? (value) => media.seek(
                                  Duration(
                                    milliseconds: (value * 1000).round(),
                                  ),
                                )
                              : null,
                        ),
                        Text(
                          '${formatMediaTime(position)} / ${duration == Duration.zero ? '—:—' : formatMediaTime(duration)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (selected && media.error != null)
                          Text(
                            media.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Row(
                children: [
                  NoteAttachmentDragHandle(
                    key: ValueKey('attachment-drag-$id'),
                    notes: notes,
                    attachment: attachment,
                  ),
                  Expanded(
                    child: Text(
                      '${attachment.kind == NoteAttachmentKind.image ? attachment.name : 'Audio attachment'} · ${attachment.sizeLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: notes.isSaving
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              useRootNavigator: false,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove attachment?'),
                                content: const Text(
                                  'Removed when you save the note. The original file on your device is not affected.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Keep it'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            await media.stopPlayback();
                            if (embedContext.node.parent != null) {
                              notes.removeAttachmentAt(
                                embedContext.node.documentOffset,
                              );
                              return;
                            }
                            var offset = 0;
                            for (final operation
                                in notes.bodyController.document
                                    .toDelta()
                                    .toJson()) {
                              final insert = operation['insert'];
                              if (NoteAttachment.embeddedId(insert) == id) {
                                notes.removeAttachmentAt(offset);
                                break;
                              }
                              offset += insert is String ? insert.length : 1;
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatMediaTime(Duration duration) =>
    '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
