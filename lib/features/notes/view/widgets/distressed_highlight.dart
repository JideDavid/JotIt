import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Keep Quill's text, links and editing intact; paint marker ink separately.
InlineSpan distressedHighlightSpanBuilder(
  BuildContext context,
  Node node,
  int textOffset,
  String text,
  TextStyle? style,
  GestureRecognizer? recognizer,
) {
  final color = style?.backgroundColor;
  if (node.style.attributes[Attribute.background.key]?.value == null ||
      color == null ||
      color.a == 0) {
    return defaultSpanBuilder(
      context,
      node,
      textOffset,
      text,
      style,
      recognizer,
    );
  }
  return DistressedHighlightSpan(
    ink: color,
    text: text,
    style: style,
    recognizer: recognizer,
    mouseCursor: recognizer != null ? SystemMouseCursors.click : null,
  );
}

class DistressedHighlightSpan extends TextSpan {
  const DistressedHighlightSpan({
    required this.ink,
    super.text,
    super.style,
    super.recognizer,
    super.mouseCursor,
  });

  final Color ink;

  @override
  void build(
    ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  }) {
    // Retain the original style for Quill's IME composition and clipboard.
    // Only the native paragraph paint receives a transparent background.
    TextSpan(
      text: text,
      style: style?.copyWith(backgroundColor: Colors.transparent),
    ).build(builder, textScaler: textScaler, dimensions: dimensions);
  }

  // The native text background is transparent, so changing only the ink color
  // must still update the paragraph's span metadata.
  @override
  RenderComparison compareTo(InlineSpan other) {
    final result = super.compareTo(other);
    if (other is DistressedHighlightSpan &&
        ink != other.ink &&
        result.index < RenderComparison.paint.index) {
      return RenderComparison.paint;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is DistressedHighlightSpan && super == other && ink == other.ink;

  @override
  int get hashCode => Object.hash(super.hashCode, ink);
}

/// Paint from the editor's actual laid-out text boxes, including bidi text,
/// large fonts and soft wrapping, without inserting inline widgets or images.
class DistressedHighlightLayer extends SingleChildRenderObjectWidget {
  const DistressedHighlightLayer({
    super.key,
    required this.repaint,
    required super.child,
  });

  final Listenable repaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDistressedHighlights(repaint);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderDistressedHighlights).repaint = repaint;
}

class _RenderDistressedHighlights extends RenderProxyBox {
  _RenderDistressedHighlights(this._repaint);

  Listenable _repaint;

  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    void visit(RenderObject object) {
      if (object is RenderParagraph && object.hasSize) {
        final runs = _inkRuns(object.text);
        if (runs.isNotEmpty) {
          final transform = object.getTransformTo(this);
          final bounds = MatrixUtils.transformRect(
            transform,
            Offset.zero & object.size,
          );
          if (bounds.overlaps(Offset.zero & size)) {
            canvas.save();
            canvas.transform(transform.storage);
            for (final run in runs) {
              final boxes = object.getBoxesForSelection(
                TextSelection(baseOffset: run.start, extentOffset: run.end),
                boxHeightStyle: ui.BoxHeightStyle.max,
              );
              final rects = _joinedRects(boxes);
              for (var index = 0; index < rects.length; index++) {
                paintDistressedMarker(
                  canvas,
                  rects[index],
                  run.ink,
                  seed: run.start * 31 + index * 131,
                );
              }
            }
            canvas.restore();
          }
        }
      }
      object.visitChildren(visit);
    }

    if (child != null) visit(child!);
    canvas.restore();
    super.paint(context, offset);
  }
}

class _InkRun {
  const _InkRun(this.start, this.end, this.ink);
  final int start;
  final int end;
  final Color ink;
}

List<_InkRun> _inkRuns(InlineSpan root) {
  final runs = <_InkRun>[];
  var offset = 0;
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      final length = span.text?.length ?? 0;
      if (span is DistressedHighlightSpan && length > 0) {
        // Adjacent pieces of the same highlight stay one brush stroke even
        // when bold, italic or text color divides them into separate spans.
        if (runs.isNotEmpty &&
            runs.last.end == offset &&
            runs.last.ink == span.ink) {
          final previous = runs.removeLast();
          runs.add(_InkRun(previous.start, offset + length, span.ink));
        } else {
          runs.add(_InkRun(offset, offset + length, span.ink));
        }
      }
      offset += length;
      span.children?.forEach(visit);
    } else if (span is PlaceholderSpan) {
      offset++;
    }
  }

  visit(root);
  return runs;
}

List<Rect> _joinedRects(List<ui.TextBox> boxes) {
  final rects =
      boxes.map((box) => box.toRect()).where((rect) => !rect.isEmpty).toList()
        ..sort((a, b) {
          final line = a.top.compareTo(b.top);
          return line == 0 ? a.left.compareTo(b.left) : line;
        });
  final joined = <Rect>[];
  for (final rect in rects) {
    if (joined.isNotEmpty &&
        (joined.last.top - rect.top).abs() < 0.5 &&
        (joined.last.bottom - rect.bottom).abs() < 0.5 &&
        rect.left <= joined.last.right + 0.5) {
      joined[joined.length - 1] = joined.last.expandToInclude(rect);
    } else {
      joined.add(rect);
    }
  }
  return joined;
}

/// Procedural dry-marker ink: a dense center, ragged edges and fine bristles.
/// The fixed seed keeps the texture still while selecting or scrolling text.
void paintDistressedMarker(
  Canvas canvas,
  Rect textBox,
  Color color, {
  int seed = 0,
}) {
  if (textBox.isEmpty || color.a == 0) return;
  final random = math.Random(seed);
  // Leave visible ink before and after the lettering, including on soft wraps.
  // This is visual padding; document text and selection offsets stay unchanged.
  final endPadding = (textBox.height * 0.3).clamp(7.0, 12.0);
  final rect = Rect.fromLTRB(
    textBox.left - endPadding,
    textBox.top + textBox.height * 0.10,
    textBox.right + endPadding,
    textBox.bottom - textBox.height * 0.10,
  );
  final roughness = math.min(1.8, rect.height * 0.09);
  final feather = math.min(9.0, rect.width * 0.15);
  final steps = math.max(2, (rect.width / 1.5).ceil());
  final stroke = Path()..fillType = PathFillType.evenOdd;
  double taper(double x) =>
      (1 - math.min(x, rect.width - x) / feather).clamp(0.0, 1.0) *
      rect.height *
      0.12;
  for (var i = 0; i <= steps; i++) {
    final x = rect.width * i / steps;
    final y = rect.top + random.nextDouble() * roughness + taper(x);
    if (i == 0) {
      stroke.moveTo(rect.left + x, y);
    } else {
      stroke.lineTo(rect.left + x, y);
    }
  }
  for (var i = steps; i >= 0; i--) {
    final x = rect.width * i / steps;
    stroke.lineTo(
      rect.left + x,
      rect.bottom - random.nextDouble() * roughness - taper(x),
    );
  }
  stroke.close();
  // Most wear stays at the edges, leaving the lettering's center legible.
  for (var i = 0; i < (rect.width * 0.9).ceil(); i++) {
    final x = rect.left + random.nextDouble() * rect.width;
    final edge = random.nextBool() ? rect.top : rect.bottom;
    final y = edge + (random.nextDouble() - 0.5) * roughness * 3;
    stroke.addOval(
      Rect.fromCircle(
        center: Offset(x, y),
        radius: 0.15 + random.nextDouble() * 0.55,
      ),
    );
  }
  for (var i = 0; i < (rect.width * 0.035).ceil(); i++) {
    stroke.addOval(
      Rect.fromCircle(
        center: Offset(
          rect.left + random.nextDouble() * rect.width,
          rect.top + random.nextDouble() * rect.height,
        ),
        radius: 0.15 + random.nextDouble() * 0.35,
      ),
    );
  }
  canvas.drawPath(stroke, Paint()..color = color);
  final bristle = Paint()
    ..color = color.withValues(alpha: color.a * 0.65)
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 18; i++) {
    final y = rect.top + 1 + random.nextDouble() * (rect.height - 2);
    bristle.strokeWidth = 0.3 + random.nextDouble() * 0.45;
    for (final left in [true, false]) {
      final edge = left ? rect.left : rect.right;
      final direction = left ? 1.0 : -1.0;
      canvas.drawLine(
        Offset(edge - direction * random.nextDouble() * 4, y),
        Offset(edge + direction * (3 + random.nextDouble() * feather), y),
        bristle,
      );
    }
  }
}
