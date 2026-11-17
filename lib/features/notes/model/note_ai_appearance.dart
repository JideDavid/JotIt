import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'note_text_style.dart';

/// Theme-aware colors are checked by the app, not left to model judgement.
class NoteAiAppearance {
  const NoteAiAppearance({required this.background, required this.foreground});
  final Color background, foreground;
  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  Map<String, dynamic> toJson() => {
    'background': hex(background),
    'foreground': hex(foreground),
    'dark': background.computeLuminance() < .3,
  };
  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (math.max(x, y) + .05) / (math.min(x, y) + .05);
  }

  Map<String, dynamic> readable(Map<String, dynamic> source) {
    final attrs = Map<String, dynamic>.of(source);
    final highlight = NoteTextStyle.colorValue(attrs['background']);
    final base = highlight ?? background;
    final text = NoteTextStyle.colorValue(attrs['color']) ?? foreground;
    if (contrast(text, base) < 4.5) {
      Color replacement;
      if (highlight != null) {
        replacement =
            contrast(Colors.black, base) >= contrast(Colors.white, base)
            ? Colors.black
            : Colors.white;
      } else if (NoteTextStyle.colorValue(attrs['color']) != null) {
        final hsl = HSLColor.fromColor(text);
        replacement = foreground;
        for (var step = 1; step <= 20; step++) {
          final candidate = hsl
              .withLightness(
                (hsl.lightness +
                        (background.computeLuminance() < .3 ? 1 : -1) *
                            step *
                            .04)
                    .clamp(0, 1),
              )
              .toColor();
          if (contrast(candidate, base) >= 4.5) {
            replacement = candidate;
            break;
          }
        }
      } else {
        replacement = foreground;
      }
      attrs['color'] = hex(replacement);
    }
    return attrs;
  }
}
