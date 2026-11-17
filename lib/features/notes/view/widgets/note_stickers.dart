import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../model/note_sticker.dart';
import '../../services/note_document_edits.dart';
import '../../view-model/note_view_model.dart';

class NoteStickerVisual extends StatelessWidget {
  const NoteStickerVisual({
    super.key,
    required this.sticker,
    this.preview = false,
  });
  final NoteSticker sticker;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final format = sticker.format;
    if (format == null) return const Text('Sticker format unavailable');
    final visual = format.visual;
    final wide = visual == StickerVisual.profile;
    final label = visual.index >= StickerVisual.label.index && !format.isDoodle;
    final width = preview ? (wide ? 184.0 : 92.0) : sticker.width;
    final height = format.isDoodle
        ? width
        : visual == StickerVisual.seal
        ? width
        : label
        ? (preview ? 40.0 : 48.0)
        : preview
        ? (wide ? 82.0 : 86.0)
        : wide
        ? 140.0
        : 166.0;
    return Transform.rotate(
      angle: sticker.rotation,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _StickerPainter(visual, Color(sticker.color)),
          child: format.isDoodle
              ? null
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 10 : 14,
                    format.hasBody ? (preview ? 17 : 28) : 5,
                    14,
                    10,
                  ),
                  child: visual == StickerVisual.profile
                      ? _profile(context, preview)
                      : Column(
                          mainAxisAlignment: format.hasBody
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!preview && visual == StickerVisual.pinned)
                              const Text(
                                '01',
                                style: TextStyle(
                                  fontFamily: 'Caveat',
                                  fontSize: 18,
                                  color: Color(0xff65513b),
                                ),
                              ),
                            Text(
                              sticker.text,
                              maxLines: visual == StickerVisual.seal ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: visual == StickerVisual.seal
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff302b31),
                                fontSize: preview
                                    ? 11
                                    : label
                                    ? 12
                                    : 14,
                                height: 1.2,
                              ),
                            ),
                            if (format.hasBody && !preview) ...[
                              const SizedBox(height: 7),
                              Expanded(
                                child: Text(
                                  sticker.body,
                                  overflow: TextOverflow.fade,
                                  style: const TextStyle(
                                    color: Color(0xff423b40),
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
        ),
      ),
    );
  }

  Widget _profile(BuildContext context, bool compact) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: compact ? 12 : 17,
        backgroundColor: Color(sticker.color),
        foregroundColor: Colors.white,
        child: Text(
          sticker.text.isEmpty ? '?' : sticker.text.characters.first,
          style: TextStyle(fontSize: compact ? 13 : 19),
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sticker.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff302b31),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '★ ${sticker.rating}/5',
                  style: const TextStyle(
                    color: Color(0xff302b31),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (!compact && sticker.meta.isNotEmpty)
              Text(
                sticker.meta,
                maxLines: 1,
                style: const TextStyle(fontSize: 10, color: Color(0xff61575b)),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                sticker.body,
                maxLines: compact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff423b40),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter(this.visual, this.color);
  final StickerVisual visual;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paper = Color.alphaBlend(
      color.withValues(alpha: .25),
      const Color(0xfffffdf8),
    );
    final fill = Paint()..color = paper;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (visual.index >= StickerVisual.star.index) {
      if (visual == StickerVisual.star || visual == StickerVisual.sparkles) {
        final count = visual == StickerVisual.star ? 10 : 8;
        for (var i = 0; i < count; i++) {
          final angle = -math.pi / 2 + i * math.pi * 2 / count;
          final radius = (i.isEven ? .43 : .19) * w;
          final p = Offset(
            w / 2 + math.cos(angle) * radius,
            h / 2 + math.sin(angle) * radius,
          );
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
      if (visual == StickerVisual.arrow) {
        path.moveTo(w * .15, h * .8);
        path.quadraticBezierTo(w * .52, h * .6, w * .82, h * .18);
        path.moveTo(w * .4, h * .18);
        path.lineTo(w * .82, h * .18);
        path.lineTo(w * .82, h * .6);
      }
      if (visual == StickerVisual.heart) {
        path.moveTo(w * .5, h * .85);
        path.cubicTo(-w * .3, h * .3, w * .15, -h * .1, w * .5, h * .28);
        path.cubicTo(w * .85, -h * .1, w * 1.3, h * .3, w * .5, h * .85);
        path.close();
      }
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .12));
      canvas.drawPath(path, line..strokeWidth = 2.8);
      return;
    }
    if (visual == StickerVisual.seal) {
      for (var i = 0; i < 40; i++) {
        final a = i * math.pi / 20;
        final r = w * (i.isEven ? .49 : .445);
        final p = Offset(w / 2 + math.cos(a) * r, h / 2 + math.sin(a) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
    } else if (visual == StickerVisual.torn) {
      path.moveTo(2, 3);
      path.lineTo(w - 2, 1);
      path.lineTo(w - 1, h - 10);
      for (var x = w - 1; x >= 0; x -= 8) {
        path.lineTo(x, h - ((x / 8).round().isEven ? 2 : 8));
      }
      path.close();
    } else if (visual == StickerVisual.ribbon) {
      path.addPolygon([
        Offset.zero,
        Offset(w, 0),
        Offset(w - 12, h / 2),
        Offset(w, h),
        Offset(0, h),
      ], true);
    } else if (visual == StickerVisual.ticket) {
      path.moveTo(0, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h / 2 - 6);
      path.arcToPoint(
        Offset(w, h / 2 + 6),
        radius: const Radius.circular(6),
        clockwise: false,
      );
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.lineTo(0, h / 2 + 6);
      path.arcToPoint(
        Offset(0, h / 2 - 6),
        radius: const Radius.circular(6),
        clockwise: false,
      );
      path.close();
    } else if (visual == StickerVisual.bubble) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h - 9),
          const Radius.circular(13),
        ),
      );
      path.addPolygon([
        Offset(9, h - 11),
        Offset(5, h),
        Offset(27, h - 11),
      ], true);
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 4, w - 2, h - 8),
          Radius.circular(visual == StickerVisual.pinned ? 12 : 5),
        ),
      );
    }
    canvas.drawShadow(path, Colors.black.withValues(alpha: .22), 3, true);
    final framed = visual == StickerVisual.frame,
        pinned = visual == StickerVisual.pinned;
    canvas.drawPath(
      path,
      fill
        ..color = framed
            ? color
            : pinned
            ? const Color(0xfffffdf8)
            : paper,
    );
    if (pinned || framed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(9, 20, w - 18, h - 30),
          const Radius.circular(4),
        ),
        fill..color = framed ? const Color(0xfffffdf8) : paper,
      );
    }
    if (visual == StickerVisual.torn || visual == StickerVisual.spiral) {
      for (var y = 38.0; y < h - 8; y += 18) {
        canvas.drawLine(
          Offset(8, y),
          Offset(w - 8, y),
          line
            ..color = color.withValues(alpha: .22)
            ..strokeWidth = .7,
        );
      }
    }
    if (visual == StickerVisual.spiral) {
      canvas.drawRect(Rect.fromLTWH(1, 4, w - 2, 12), fill..color = color);
      for (var x = 12.0; x < w; x += 18) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, 5, 20),
            const Radius.circular(3),
          ),
          line
            ..color = const Color(0xff6c7076)
            ..strokeWidth = 2,
        );
      }
    }
    if (visual == StickerVisual.tape) {
      canvas.save();
      canvas.translate(w / 2, 8);
      canvas.rotate(-.1);
      canvas.drawRect(
        const Rect.fromLTWH(-25, -8, 50, 18),
        fill..color = const Color(0xccd1bd8e),
      );
      canvas.restore();
    }
    if (visual == StickerVisual.folded) {
      final fold = Path()
        ..moveTo(w - 23, h - 4)
        ..lineTo(w - 1, h - 26)
        ..lineTo(w - 1, h - 4)
        ..close();
      canvas.drawPath(fold, fill..color = color.withValues(alpha: .4));
    }
    if (visual == StickerVisual.envelope) {
      canvas.drawPath(
        Path()
          ..moveTo(1, 4)
          ..lineTo(w / 2, 34)
          ..lineTo(w - 1, 4)
          ..close(),
        fill..color = color.withValues(alpha: .35),
      );
      canvas.drawLine(
        Offset(1, h - 4),
        Offset(w * .4, h * .65),
        line
          ..color = color.withValues(alpha: .3)
          ..strokeWidth = 1,
      );
      canvas.drawLine(Offset(w - 1, h - 4), Offset(w * .6, h * .65), line);
    }
    if (pinned || framed) {
      final pinColor = framed ? Color.lerp(color, Colors.black, .55)! : color;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2, 15), width: 24, height: 10),
        fill..color = pinColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w / 2 - 8, 0, 16, 19),
          const Radius.circular(9),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [Color.lerp(pinColor, Colors.white, .35)!, pinColor],
          ).createShader(Rect.fromLTWH(w / 2 - 8, 0, 16, 19)),
      );
    }
    if (visual == StickerVisual.profile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 4, w - 2, h - 8),
          const Radius.circular(5),
        ),
        line
          ..color = color
          ..strokeWidth = 1,
      );
    }
    if (visual == StickerVisual.seal) {
      canvas.drawCircle(
        Offset(w / 2, h / 2),
        w * .36,
        line
          ..color = color
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_StickerPainter old) =>
      old.visual != visual || old.color != color;
}

Future<int?> pickStickerColor(BuildContext context, int current) async {
  final text = TextEditingController(
    text: (current & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase(),
  );
  var valid = true;
  final result = await showDialog<int>(
    context: context,
    useRootNavigator: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Sticker color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              children: [
                for (final color in StickerCatalog.colors)
                  IconButton(
                    tooltip:
                        '#${(color.toARGB32() & 0xffffff).toRadixString(16)}',
                    onPressed: () => Navigator.pop(context, color.toARGB32()),
                    icon: Icon(Icons.circle, color: color, size: 30),
                  ),
              ],
            ),
            TextField(
              controller: text,
              maxLength: 7,
              decoration: InputDecoration(
                labelText: 'Custom hex color',
                prefixText: '#',
                errorText: valid ? null : 'Use six hex digits.',
              ),
              onChanged: (_) => setState(() => valid = true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final hex = text.text.replaceFirst('#', '').trim();
              if (!RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(hex)) {
                setState(() => valid = false);
                return;
              }
              Navigator.pop(context, int.parse('ff$hex', radix: 16));
            },
            child: const Text('Use color'),
          ),
        ],
      ),
    ),
  );
  // Dialog exit animations can still read controllers in the closing route.
  Future<void>.delayed(const Duration(seconds: 1), text.dispose);
  return result;
}

Future<void> editNoteSticker(
  BuildContext context,
  NoteViewModel notes,
  NoteSticker sticker,
) async {
  if (!notes.canMoveAttachments || sticker.format == null) return;
  final document = notes.bodyController.document;
  await showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) =>
        _StickerEditor(notes: notes, sticker: sticker, document: document),
  );
}

class _StickerEditor extends StatefulWidget {
  const _StickerEditor({
    required this.notes,
    required this.sticker,
    required this.document,
  });
  final NoteViewModel notes;
  final NoteSticker sticker;
  final Document document;
  @override
  State<_StickerEditor> createState() => _StickerEditorState();
}

class _StickerEditorState extends State<_StickerEditor> {
  late NoteSticker _sticker = widget.sticker;
  late final _text = TextEditingController(text: _sticker.text),
      _body = TextEditingController(text: _sticker.body),
      _meta = TextEditingController(text: _sticker.meta);
  bool get _allowed =>
      identical(widget.document, widget.notes.bodyController.document) &&
      widget.notes.canMoveAttachments;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Edit ${_sticker.format!.name}'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: NoteStickerVisual(sticker: _sticker),
                ),
              ),
            ),
            if (!_sticker.format!.isDoodle) ...[
              TextField(
                controller: _text,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Sticker text'),
                onChanged: (v) =>
                    setState(() => _sticker = _sticker.copyWith(text: v)),
              ),
              if (_sticker.format!.hasBody)
                TextField(
                  controller: _body,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (v) =>
                      setState(() => _sticker = _sticker.copyWith(body: v)),
                ),
              if (_sticker.format!.visual == StickerVisual.profile) ...[
                TextField(
                  controller: _meta,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Detail or date',
                  ),
                  onChanged: (v) =>
                      setState(() => _sticker = _sticker.copyWith(meta: v)),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _sticker.rating,
                  decoration: const InputDecoration(labelText: 'Rating'),
                  items: [
                    for (var i = 1; i <= 5; i++)
                      DropdownMenuItem(value: i, child: Text('$i/5')),
                  ],
                  onChanged: (v) =>
                      setState(() => _sticker = _sticker.copyWith(rating: v)),
                ),
              ],
            ],
            TextButton.icon(
              onPressed: () async {
                final color = await pickStickerColor(context, _sticker.color);
                if (mounted && color != null) {
                  setState(() => _sticker = _sticker.copyWith(color: color));
                }
              },
              icon: Icon(Icons.circle, color: Color(_sticker.color)),
              label: const Text('Change color'),
            ),
            const Align(alignment: Alignment.centerLeft, child: Text('Size')),
            Slider(
              value: _sticker.width,
              min: 28,
              max: 320,
              onChanged: (v) =>
                  setState(() => _sticker = _sticker.copyWith(width: v)),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Rotation'),
            ),
            Slider(
              value: _sticker.rotation,
              min: -.5,
              max: .5,
              onChanged: (v) =>
                  setState(() => _sticker = _sticker.copyWith(rotation: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Free placement on the page'),
              subtitle: const Text('Turn off to move with text.'),
              value: _sticker.free,
              onChanged: (v) =>
                  setState(() => _sticker = _sticker.copyWith(free: v)),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          if (_allowed) widget.notes.updateSticker(_sticker.id, null);
          Navigator.pop(context);
        },
        child: const Text('Delete'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_allowed) widget.notes.updateSticker(_sticker.id, _sticker);
          Navigator.pop(context);
        },
        child: const Text('Apply'),
      ),
    ],
  );
  @override
  void dispose() {
    _text.dispose();
    _body.dispose();
    _meta.dispose();
    super.dispose();
  }
}

class NoteStickerDrag {
  const NoteStickerDrag({
    required this.document,
    this.id,
    this.format,
    this.free = false,
    this.color = 0xffe9af35,
  });
  final Document document;
  final String? id;
  final StickerFormat? format;
  final bool free;
  final int color;
}

class StickerDraggable extends StatelessWidget {
  const StickerDraggable({
    super.key,
    required this.notes,
    required this.sticker,
    required this.child,
  });
  final NoteViewModel notes;
  final NoteSticker sticker;
  final Widget child;
  @override
  Widget build(BuildContext context) => LongPressDraggable<NoteStickerDrag>(
    data: NoteStickerDrag(
      document: notes.bodyController.document,
      id: sticker.id,
      free: sticker.free,
      color: sticker.color,
    ),
    maxSimultaneousDrags: notes.canMoveAttachments ? 1 : 0,
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: Material(
      type: MaterialType.transparency,
      child: Opacity(opacity: .8, child: NoteStickerVisual(sticker: sticker)),
    ),
    childWhenDragging: Opacity(opacity: .25, child: child),
    child: child,
  );
}

class NoteStickerEmbedBuilder extends EmbedBuilder {
  NoteStickerEmbedBuilder(this.notes);
  final NoteViewModel notes;
  @override
  String get key => NoteSticker.embedType;
  @override
  bool get expanded => false;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final sticker = NoteSticker.decode(embedContext.node.value.data);
    if (sticker == null || sticker.format == null) {
      return const Text('[Sticker unavailable]');
    }
    if (sticker.free) return const SizedBox(width: 1, height: 1);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: StickerDraggable(
        notes: notes,
        sticker: sticker,
        child: GestureDetector(
          onTap: () => editNoteSticker(context, notes, sticker),
          child: Semantics(
            button: true,
            label: 'Edit ${sticker.format!.name} sticker',
            child: NoteStickerVisual(
              sticker: sticker.copyWith(
                width: sticker.width.clamp(
                  28,
                  MediaQuery.sizeOf(context).width - 80,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoteStickerTray extends StatefulWidget {
  const NoteStickerTray({
    super.key,
    required this.notes,
    required this.selection,
    required this.onClose,
  });
  final NoteViewModel notes;
  final TextSelection selection;
  final VoidCallback onClose;
  @override
  State<NoteStickerTray> createState() => _NoteStickerTrayState();
}

class _NoteStickerTrayState extends State<NoteStickerTray> {
  String _category = 'Paper notes';
  bool _free = false;
  int _color = 0xffe9af35;
  @override
  Widget build(BuildContext context) {
    final formats = StickerCatalog.formats
        .where((f) => f.category == _category)
        .toList();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Stickers',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Hold and drag · tap to insert',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: 'Close stickers',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('On the page'),
                    icon: Icon(Icons.open_with, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('In text lines'),
                    icon: Icon(Icons.text_fields, size: 16),
                  ),
                ],
                selected: {_free},
                onSelectionChanged: (v) => setState(() => _free = v.first),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final category in {
                    'Paper notes',
                    'Cards',
                    'Labels',
                    'Doodles',
                  })
                    TextButton(
                      onPressed: () => setState(() => _category = category),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _category == category
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Color', style: TextStyle(fontSize: 11)),
                  for (final color in StickerCatalog.colors)
                    IconButton(
                      tooltip:
                          'Use #${(color.toARGB32() & 0xffffff).toRadixString(16)}',
                      onPressed: () =>
                          setState(() => _color = color.toARGB32()),
                      isSelected: _color == color.toARGB32(),
                      icon: Icon(
                        _color == color.toARGB32()
                            ? Icons.check_circle
                            : Icons.circle,
                        color: color,
                        size: 25,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Custom sticker color',
                    onPressed: () async {
                      final color = await pickStickerColor(context, _color);
                      if (mounted && color != null) {
                        setState(() => _color = color);
                      }
                    },
                    icon: const Icon(Icons.palette_outlined),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: formats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final format = formats[i];
                  final sample = NoteSticker(
                    id: 'catalog',
                    formatId: format.id,
                    text: format.text,
                    body: format.body,
                    color: _color,
                    width: format.width,
                    free: _free,
                  );
                  return LongPressDraggable<NoteStickerDrag>(
                    data: NoteStickerDrag(
                      document: widget.notes.bodyController.document,
                      format: format,
                      free: _free,
                      color: _color,
                    ),
                    maxSimultaneousDrags: widget.notes.canMoveAttachments
                        ? 1
                        : 0,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      type: MaterialType.transparency,
                      child: NoteStickerVisual(sticker: sample),
                    ),
                    child: InkWell(
                      onTap: () => widget.notes.insertSticker(
                        format,
                        selection: widget.selection,
                        free: _free,
                        color: _color,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: NoteStickerVisual(
                                sticker: sample,
                                preview: true,
                              ),
                            ),
                          ),
                          Text(
                            format.name,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteStickerLayer extends StatefulWidget {
  const NoteStickerLayer({
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
  State<NoteStickerLayer> createState() => _NoteStickerLayerState();
}

class _NoteStickerLayerState extends State<NoteStickerLayer> {
  final _viewport = GlobalKey();
  bool _pending = false;
  Offset? _pointer;
  Timer? _autoScroll;
  @override
  void initState() {
    super.initState();
    widget.notes.bodyController.addListener(_schedule);
    widget.scrollController.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    if (_pending) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (mounted) setState(() {});
    });
  }

  bool _accept(NoteStickerDrag data) =>
      identical(data.document, widget.notes.bodyController.document) &&
      widget.notes.canMoveAttachments &&
      (data.format != null ||
          widget.notes.stickers.any((s) => s.sticker.id == data.id));
  void _clear() {
    _autoScroll?.cancel();
    _autoScroll = null;
    if (mounted) setState(() => _pointer = null);
  }

  void _track(DragTargetDetails<NoteStickerDrag> details) {
    setState(() => _pointer = details.offset);
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 30), (_) {
      final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
      final pointer = _pointer;
      final scroll = widget.scrollController;
      if (box == null ||
          pointer == null ||
          !scroll.hasClients ||
          !_accept(details.data)) {
        return;
      }
      final y = box.globalToLocal(pointer).dy;
      final step = y < 48
          ? -10.0
          : y > box.size.height - 48
          ? 10.0
          : 0.0;
      if (step != 0) {
        scroll.jumpTo(
          (scroll.offset + step).clamp(
            scroll.position.minScrollExtent,
            scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => DragTarget<NoteStickerDrag>(
    onWillAcceptWithDetails: (d) => _accept(d.data),
    onMove: _track,
    onLeave: (_) => _clear(),
    onAcceptWithDetails: (details) {
      final editor = widget.editorKey.currentState?.renderEditor;
      final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
      if (editor != null && box != null && _accept(details.data)) {
        final position = editor.getPositionForOffset(details.offset);
        final target = position.offset.clamp(
          0,
          widget.notes.bodyController.document.length - 1,
        );
        final point = box.globalToLocal(details.offset);
        final caret = box.globalToLocal(
          editor.localToGlobal(
            editor.getLocalRectForCaret(TextPosition(offset: target)).topLeft,
          ),
        );
        final data = details.data;
        NoteSticker? existing;
        for (final s in widget.notes.stickers) {
          if (s.sticker.id == data.id) existing = s.sticker;
        }
        final width = existing?.width ?? data.format?.width ?? 150;
        final x = ((point.dx - 16) / math.max(1, box.size.width - width - 32))
            .clamp(0.0, 1.0)
            .toDouble();
        final dy = point.dy - caret.dy;
        if (existing != null) {
          widget.notes.moveSticker(
            existing.id,
            target,
            existing.copyWith(x: x, dy: dy),
          );
        } else if (data.format != null) {
          widget.notes.insertSticker(
            data.format!,
            selection: TextSelection.collapsed(offset: target),
            free: data.free,
            color: data.color,
            x: x,
            dy: dy,
          );
        }
      }
      _clear();
    },
    builder: (context, accepted, rejected) => LayoutBuilder(
      builder: (context, constraints) {
        final editor = widget.editorKey.currentState?.renderEditor;
        final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
        return ClipRect(
          child: Stack(
            key: _viewport,
            fit: StackFit.expand,
            children: [
              widget.child,
              if (editor != null && box != null)
                for (final placed in widget.notes.stickers.where(
                  (p) => p.sticker.free,
                ))
                  ..._positioned(
                    context,
                    placed,
                    editor,
                    box,
                    constraints.maxWidth,
                  ),
              if (_pointer != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: box == null
                      ? 2
                      : box
                            .globalToLocal(_pointer!)
                            .dy
                            .clamp(2, math.max(2, constraints.maxHeight - 4)),
                  child: IgnorePointer(
                    child: Container(
                      height: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
  List<Widget> _positioned(
    BuildContext context,
    PlacedSticker placed,
    RenderEditor editor,
    RenderBox box,
    double available,
  ) {
    final sticker = placed.sticker;
    if (sticker.format == null) return [];
    final caret = box.globalToLocal(
      editor.localToGlobal(
        editor
            .getLocalRectForCaret(TextPosition(offset: placed.offset))
            .topLeft,
      ),
    );
    final width = math
        .min(sticker.width, math.max(28.0, available - 32))
        .toDouble();
    return [
      Positioned(
        left: 16 + sticker.x * math.max(0, available - width - 32),
        top: caret.dy + sticker.dy,
        width: width,
        child: StickerDraggable(
          notes: widget.notes,
          sticker: sticker,
          child: GestureDetector(
            onTap: () => editNoteSticker(context, widget.notes, sticker),
            child: NoteStickerVisual(sticker: sticker.copyWith(width: width)),
          ),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    widget.notes.bodyController.removeListener(_schedule);
    widget.scrollController.removeListener(_schedule);
    _autoScroll?.cancel();
    super.dispose();
  }
}
