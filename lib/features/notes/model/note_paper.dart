import 'dart:convert';

enum NotePaperPattern {
  plain('Plain'),
  dots('Dotted'),
  ruled('Ruled'),
  grid('Grid'),
  diamond('Diamond'),
  gradient('Soft wash');

  const NotePaperPattern(this.label);
  final String label;

  bool get hasSpacing => this != plain && this != gradient;
}

enum NotePaperTone {
  theme('Theme'),
  parchment('Parchment'),
  sage('Sage'),
  mist('Mist'),
  rose('Rose');

  const NotePaperTone(this.label);
  final String label;
}

class NotePaper {
  const NotePaper({
    this.pattern = NotePaperPattern.plain,
    this.tone = NotePaperTone.theme,
    this.spacing = 28,
    this.intensity = 0.10,
  }) : assert(spacing >= 16 && spacing <= 48),
       assert(intensity >= 0.04 && intensity <= 0.20);

  final NotePaperPattern pattern;
  final NotePaperTone tone;
  final double spacing;
  final double intensity;

  factory NotePaper.decode(String? encoded) {
    if (encoded == null) return const NotePaper();
    try {
      final data = jsonDecode(encoded);
      if (data is! Map || data['version'] != 1) return const NotePaper();
      final spacing = data['spacing'];
      final intensity = data['intensity'];
      return NotePaper(
        pattern: NotePaperPattern.values.firstWhere(
          (pattern) => pattern.name == data['pattern'],
          orElse: () => NotePaperPattern.plain,
        ),
        tone: NotePaperTone.values.firstWhere(
          (tone) => tone.name == data['tone'],
          orElse: () => NotePaperTone.theme,
        ),
        spacing: spacing is num && spacing.isFinite
            ? spacing.toDouble().clamp(16, 48)
            : 28,
        intensity: intensity is num && intensity.isFinite
            ? intensity.toDouble().clamp(0.04, 0.20)
            : 0.10,
      );
    } catch (_) {
      return const NotePaper();
    }
  }

  String? encode() => this == const NotePaper()
      ? null
      : jsonEncode({
          'version': 1,
          'pattern': pattern.name,
          'tone': tone.name,
          'spacing': spacing,
          'intensity': intensity,
        });

  NotePaper copyWith({
    NotePaperPattern? pattern,
    NotePaperTone? tone,
    double? spacing,
    double? intensity,
  }) => NotePaper(
    pattern: pattern ?? this.pattern,
    tone: tone ?? this.tone,
    spacing: spacing ?? this.spacing,
    intensity: intensity ?? this.intensity,
  );

  @override
  bool operator ==(Object other) =>
      other is NotePaper &&
      pattern == other.pattern &&
      tone == other.tone &&
      spacing == other.spacing &&
      intensity == other.intensity;

  @override
  int get hashCode => Object.hash(pattern, tone, spacing, intensity);
}
