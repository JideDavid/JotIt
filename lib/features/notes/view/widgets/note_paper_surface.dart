import 'package:flutter/material.dart';
import '../../model/note_paper.dart';

class NotePaperSurface extends StatelessWidget {
  const NotePaperSurface({
    super.key,
    required this.paper,
    required this.child,
    this.scrollController,
  });

  final NotePaper paper;
  final Widget child;
  final ScrollController? scrollController;

  static Color backgroundFor(NotePaperTone tone, ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return switch (tone) {
      NotePaperTone.theme => theme.scaffoldBackgroundColor,
      NotePaperTone.parchment => Color(dark ? 0xff29251e : 0xfff8f1df),
      NotePaperTone.sage => Color(dark ? 0xff202923 : 0xffedf3e9),
      NotePaperTone.mist => Color(dark ? 0xff202731 : 0xffedf2f8),
      NotePaperTone.rose => Color(dark ? 0xff2d2328 : 0xfff8edef),
    };
  }

  static Color foregroundFor(NotePaperTone tone, ThemeData theme) =>
      ThemeData.estimateBrightnessForColor(backgroundFor(tone, theme)) ==
          Brightness.dark
      ? const Color(0xffeeeae2)
      : const Color(0xff292b30);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = backgroundFor(paper.tone, theme);
    final foreground = foregroundFor(paper.tone, theme);
    Widget paintedChild() => CustomPaint(
      painter: NotePaperPainter(
        paper: paper,
        background: background,
        foreground: foreground,
        scrollOffset: scrollController?.hasClients == true
            ? scrollController!.offset
            : 0,
      ),
      child: child,
    );

    return ClipRect(
      child: scrollController == null
          ? paintedChild()
          : ListenableBuilder(
              listenable: scrollController!,
              builder: (context, _) => paintedChild(),
            ),
    );
  }
}

class NotePaperDecoration extends Decoration {
  const NotePaperDecoration({
    required this.paper,
    required this.background,
    required this.foreground,
    this.intensityScale = 1,
  });

  final NotePaper paper;
  final Color background;
  final Color foreground;
  final double intensityScale;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _NotePaperBoxPainter(this, onChanged);
}

class _NotePaperBoxPainter extends BoxPainter {
  _NotePaperBoxPainter(this.decoration, super.onChanged);

  final NotePaperDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    NotePaperPainter(
      paper: decoration.paper,
      background: decoration.background,
      foreground: decoration.foreground,
      intensityScale: decoration.intensityScale,
    ).paint(canvas, size);
    canvas.restore();
  }
}

class NotePaperPainter extends CustomPainter {
  NotePaperPainter({
    required this.paper,
    required this.background,
    required this.foreground,
    this.scrollOffset = 0,
    this.intensityScale = 1,
  });

  final NotePaper paper;
  final Color background;
  final Color foreground;
  final double scrollOffset;
  final double intensityScale;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = background);
    if (paper.pattern == NotePaperPattern.plain) return;
    final intensity = paper.intensity * intensityScale;
    if (paper.pattern == NotePaperPattern.gradient) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                const Color(0xffc89c59).withValues(alpha: intensity),
                background,
              ),
              background,
              Color.alphaBlend(
                const Color(0xff6f9990).withValues(alpha: intensity),
                background,
              ),
            ],
          ).createShader(bounds),
      );
      return;
    }
    final ink = Paint()
      ..color = foreground.withValues(alpha: intensity)
      ..strokeWidth = 0.7;
    final spacing = paper.spacing;
    final phase = (16 - scrollOffset) % spacing;
    if (paper.pattern == NotePaperPattern.dots) {
      for (var vertical = phase; vertical < size.height; vertical += spacing) {
        for (
          var horizontal = 24.0;
          horizontal < size.width;
          horizontal += spacing
        ) {
          canvas.drawCircle(Offset(horizontal, vertical), 1, ink);
        }
      }
      return;
    }
    if (paper.pattern == NotePaperPattern.diamond) {
      final diagonalPhase = (16 + scrollOffset) % (spacing * 2);
      for (
        var origin = -size.height - spacing * 2;
        origin < size.width + size.height + spacing * 2;
        origin += spacing * 2
      ) {
        canvas.drawLine(
          Offset(origin + diagonalPhase, 0),
          Offset(origin + diagonalPhase + size.height, size.height),
          ink,
        );
        canvas.drawLine(
          Offset(origin - diagonalPhase, 0),
          Offset(origin - diagonalPhase - size.height, size.height),
          ink,
        );
      }
      return;
    }
    for (var vertical = phase; vertical < size.height; vertical += spacing) {
      canvas.drawLine(Offset(0, vertical), Offset(size.width, vertical), ink);
    }
    if (paper.pattern == NotePaperPattern.grid) {
      for (
        var horizontal = 24.0;
        horizontal < size.width;
        horizontal += spacing
      ) {
        canvas.drawLine(
          Offset(horizontal, 0),
          Offset(horizontal, size.height),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(NotePaperPainter oldDelegate) =>
      paper != oldDelegate.paper ||
      background != oldDelegate.background ||
      foreground != oldDelegate.foreground ||
      intensityScale != oldDelegate.intensityScale ||
      scrollOffset != oldDelegate.scrollOffset;
}
