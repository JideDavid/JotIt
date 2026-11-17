import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../model/note_attachment.dart';
import '../../view-model/note_view_model.dart';

class NoteAttachmentDrag {
  const NoteAttachmentDrag(this.document, this.id);

  final Document document;
  final String id;
}

class NoteAttachmentDragHandle extends StatelessWidget {
  const NoteAttachmentDragHandle({
    super.key,
    required this.notes,
    required this.attachment,
  });

  final NoteViewModel notes;
  final NoteAttachment attachment;

  @override
  Widget build(BuildContext context) => Draggable<NoteAttachmentDrag>(
    data: NoteAttachmentDrag(notes.bodyController.document, attachment.id),
    maxSimultaneousDrags: notes.canMoveAttachments ? 1 : 0,
    dragAnchorStrategy: pointerDragAnchorStrategy,
    onDragStarted: () => FocusManager.instance.primaryFocus?.unfocus(),
    feedback: Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                attachment.kind == NoteAttachmentKind.image
                    ? Icons.image_outlined
                    : Icons.audio_file_outlined,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    childWhenDragging: const SizedBox(width: 48, height: 48),
    child: MouseRegion(
      cursor: notes.canMoveAttachments
          ? SystemMouseCursors.grab
          : SystemMouseCursors.basic,
      child: Tooltip(
        message: 'Drag to move attachment between text lines',
        child: Semantics(
          label: 'Drag to move ${attachment.name} between text lines',
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.drag_indicator),
          ),
        ),
      ),
    ),
  );
}

/// Resolve drops against Quill's actual text layout, including wrapped lines.
class NoteAttachmentDragLayer extends StatefulWidget {
  const NoteAttachmentDragLayer({
    super.key,
    required this.notes,
    required this.editorKey,
    required this.scrollController,
    required this.child,
  });

  final NoteViewModel notes;
  final GlobalKey<EditorState> editorKey;
  final ScrollController scrollController;
  final Widget child;

  @override
  State<NoteAttachmentDragLayer> createState() =>
      _NoteAttachmentDragLayerState();
}

class _NoteAttachmentDragLayerState extends State<NoteAttachmentDragLayer> {
  final _viewportKey = GlobalKey();
  Offset? _pointer;
  int? _target;
  double? _markerY;
  Timer? _scrollTimer;
  NoteAttachmentDrag? _drag;

  bool _accepts(NoteAttachmentDrag data) =>
      identical(data.document, widget.notes.bodyController.document) &&
      widget.notes.canMoveAttachments &&
      widget.notes.attachmentById(data.id) != null;

  void _update(DragTargetDetails<NoteAttachmentDrag> details) {
    if (!_accepts(details.data)) {
      _clear();
      return;
    }
    _drag = details.data;
    _pointer = details.offset;
    _resolve();
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
      final data = _drag;
      if (data == null || !_accepts(data)) {
        _clear();
        return;
      }
      final viewport =
          _viewportKey.currentContext?.findRenderObject() as RenderBox?;
      final scroll = widget.scrollController;
      if (viewport == null || _pointer == null || !scroll.hasClients) return;
      final y = viewport.globalToLocal(_pointer!).dy;
      const edge = 56.0;
      final step = y < edge
          ? -12.0 * (1 - y / edge).clamp(0, 1)
          : y > viewport.size.height - edge
          ? 12.0 * (1 - (viewport.size.height - y) / edge).clamp(0, 1)
          : 0.0;
      if (step == 0) return;
      final next = (scroll.offset + step).clamp(
        scroll.position.minScrollExtent,
        scroll.position.maxScrollExtent,
      );
      if (next == scroll.offset) return;
      scroll.jumpTo(next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pointer != null) _resolve();
      });
    });
  }

  void _resolve() {
    final editor = widget.editorKey.currentState?.renderEditor;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final pointer = _pointer;
    if (editor == null || viewport == null || pointer == null) return;
    final position = editor.getPositionForOffset(pointer);
    final range = editor.getLineAtOffset(position);
    final caret = editor.getLocalRectForCaret(position);
    final below = editor.globalToLocal(pointer).dy > caret.center.dy;
    final text = widget.notes.bodyController.document.toPlainText();
    var target = below ? range.end : range.start;
    // Crossing a hard line break places the embed before the next paragraph.
    if (below && target < text.length - 1 && text[target] == '\n') target++;
    target = target.clamp(0, text.length - 1);
    final marker = viewport
        .globalToLocal(
          editor.localToGlobal(Offset(0, below ? caret.bottom : caret.top)),
        )
        .dy;
    setState(() {
      _target = target;
      _markerY = marker.clamp(2, viewport.size.height - 4);
    });
  }

  void _clear() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _pointer = null;
    _drag = null;
    if (mounted) {
      setState(() {
        _target = null;
        _markerY = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => DragTarget<NoteAttachmentDrag>(
    onWillAcceptWithDetails: (details) => _accepts(details.data),
    onMove: _update,
    onLeave: (_) => _clear(),
    onAcceptWithDetails: (details) {
      if (_accepts(details.data)) {
        _pointer = details.offset;
        _resolve();
        final target = _target;
        if (target != null) {
          widget.notes.moveAttachment(details.data.id, target);
        }
      }
      _clear();
    },
    builder: (context, candidates, rejected) => Stack(
      key: _viewportKey,
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_markerY != null && widget.notes.canMoveAttachments)
          Positioned(
            left: 24,
            right: 24,
            top: _markerY,
            child: IgnorePointer(
              child: Container(
                key: const ValueKey('attachment-drop-marker'),
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }
}
