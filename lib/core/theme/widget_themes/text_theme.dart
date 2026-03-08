import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// Custom Class for white & black Text Themes
class TTextTheme {
  TTextTheme._(); // To avoid creating instances

  /// Customizable white Text Theme
  static TextTheme lightTextTheme = TextTheme(
    headlineLarge: const TextStyle().copyWith(fontSize: 32.0, fontWeight: FontWeight.bold, color: ZColors.black),
    headlineMedium: const TextStyle().copyWith(fontSize: 24.0, fontWeight: FontWeight.w600, color: ZColors.black),
    headlineSmall: const TextStyle().copyWith(fontSize: 18.0, fontWeight: FontWeight.w600, color: ZColors.black),

    titleLarge: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w600, color: ZColors.black),
    titleMedium: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w500, color: ZColors.black),
    titleSmall: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w400, color: ZColors.black),

    bodyLarge: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w500, color: ZColors.black),
    bodyMedium: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.normal, color: ZColors.black),
    bodySmall: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w300, color: ZColors.darkGrey),

    labelLarge: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: ZColors.black),
    labelMedium: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: ZColors.black.withAlpha((255 * 0.5).toInt())),
  );

  /// Customizable black Text Theme
  static TextTheme darkTextTheme = TextTheme(
    headlineLarge: const TextStyle().copyWith(fontSize: 32.0, fontWeight: FontWeight.bold, color: ZColors.white),
    headlineMedium: const TextStyle().copyWith(fontSize: 24.0, fontWeight: FontWeight.w600, color: ZColors.white),
    headlineSmall: const TextStyle().copyWith(fontSize: 18.0, fontWeight: FontWeight.w600, color: ZColors.white),

    titleLarge: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w600, color: ZColors.white),
    titleMedium: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w500, color: ZColors.white),
    titleSmall: const TextStyle().copyWith(fontSize: 16.0, fontWeight: FontWeight.w400, color: ZColors.white),

    bodyLarge: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w500, color: ZColors.white),
    bodyMedium: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.normal, color: ZColors.white),
    bodySmall: const TextStyle().copyWith(fontSize: 14.0, fontWeight: FontWeight.w300, color: ZColors.lightGrey),

    labelLarge: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: ZColors.white),
    labelMedium: const TextStyle().copyWith(fontSize: 12.0, fontWeight: FontWeight.normal, color: ZColors.white.withAlpha((0.5).toInt())),
  );
}
