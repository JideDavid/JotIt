import 'package:flutter/material.dart';
import '../../features/notes/model/note_card_color.dart';

class QuietPalette extends ThemeExtension<QuietPalette> {
  const QuietPalette({
    required this.noteSurfaces,
    required this.markers,
    required this.success,
  });

  final List<Color> noteSurfaces;
  final List<Color> markers;
  final Color success;

  Color cardSurface(int value) {
    final normalized = NoteCardColor.normalize(value);
    if (!NoteCardColor.isCustom(normalized)) return noteSurfaces[normalized];
    final dark = noteSurfaces.first.computeLuminance() < 0.5;
    return Color.alphaBlend(
      Color(normalized).withValues(alpha: dark ? 0.12 : 0.08),
      noteSurfaces.first,
    );
  }

  Color cardMarker(int value) {
    final normalized = NoteCardColor.normalize(value);
    if (!NoteCardColor.isCustom(normalized)) return markers[normalized];
    final dark = noteSurfaces.first.computeLuminance() < 0.5;
    final hsl = HSLColor.fromColor(Color(normalized));
    return hsl
        .withLightness(
          dark ? hsl.lightness.clamp(0.72, 1) : hsl.lightness.clamp(0, 0.4),
        )
        .toColor();
  }

  static QuietPalette of(BuildContext context) =>
      Theme.of(context).extension<QuietPalette>()!;

  static const light = QuietPalette(
    noteSurfaces: [
      Color(0xffffffff),
      Color(0xfff5efe7),
      Color(0xfff1f2e6),
      Color(0xffecf2e9),
      Color(0xffe9eff8),
      Color(0xfff1ebf6),
      Color(0xfff7eaf1),
      Color(0xfff5ebed),
      Color(0xfff6ece7),
    ],
    markers: [
      Color(0xffa46a00),
      Color(0xff8c6c4b),
      Color(0xff727a37),
      Color(0xff38764c),
      Color(0xff426da9),
      Color(0xff8865a7),
      Color(0xffa04b80),
      Color(0xffa04d63),
      Color(0xffa45642),
    ],
    success: Color(0xff276342),
  );

  static const dark = QuietPalette(
    noteSurfaces: [
      Color(0xff22252a),
      Color(0xff302922),
      Color(0xff2c3021),
      Color(0xff283b30),
      Color(0xff263447),
      Color(0xff332a40),
      Color(0xff3b2836),
      Color(0xff422d32),
      Color(0xff3d2c25),
    ],
    markers: [
      Color(0xfff5b840),
      Color(0xffcba780),
      Color(0xffc1c47e),
      Color(0xff95c4a3),
      Color(0xff9db9e5),
      Color(0xffc1a5dd),
      Color(0xffdaa2c4),
      Color(0xffdca0b1),
      Color(0xffd8a492),
    ],
    success: Color(0xff9cd2b0),
  );

  @override
  QuietPalette copyWith({
    List<Color>? noteSurfaces,
    List<Color>? markers,
    Color? success,
  }) => QuietPalette(
    noteSurfaces: noteSurfaces ?? this.noteSurfaces,
    markers: markers ?? this.markers,
    success: success ?? this.success,
  );

  @override
  QuietPalette lerp(covariant QuietPalette? other, double fraction) {
    if (other == null) return this;
    return QuietPalette(
      noteSurfaces: List.generate(
        noteSurfaces.length,
        (index) => Color.lerp(
          noteSurfaces[index],
          other.noteSurfaces[index],
          fraction,
        )!,
      ),
      markers: List.generate(
        markers.length,
        (index) => Color.lerp(markers[index], other.markers[index], fraction)!,
      ),
      success: Color.lerp(success, other.success, fraction)!,
    );
  }
}
